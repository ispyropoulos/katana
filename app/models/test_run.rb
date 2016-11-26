class TestRun < ActiveRecord::Base
  # For redis_live_update_resource_key
  include Models::RedisLiveUpdates
  belongs_to :tracked_branch
  belongs_to :project
  belongs_to :initiator, class_name: "User"
  has_many :test_jobs, dependent: :delete_all, inverse_of: :test_run

  delegate :completed_at, to: :last_file_run, allow_nil: true

  scope :setting_up, -> { where(status: TestStatus::SETUP) }
  scope :queued, -> { where(status: TestStatus::QUEUED) }
  scope :running, -> { where(status: TestStatus::RUNNING) }
  scope :passed, -> { where(status: TestStatus::PASSED) }
  scope :failed, -> { where(status: TestStatus::FAILED) }
  scope :error, -> { where(status: TestStatus::ERROR) }
  scope :cancelled, -> { where(status: TestStatus::CANCELLED) }
  scope :terminal_status, -> {
    where(status: [TestStatus::PASSED, TestStatus::FAILED, TestStatus::ERROR])
  }

  validates :project_id, presence: true
  validates :commit_sha, presence: true

  before_validation :set_run_index,
    if: ->{ run_index.nil? && (tracked_branch.present? || project.present?) }
  before_create :cancel_queued_runs_of_same_branch, if: -> { tracked_branch }
  after_save :cancel_test_jobs,
    if: ->{ status_changed? && self[:status] == TestStatus::CANCELLED }

  #https://github.com/mperham/sidekiq/wiki/Problems-and-Troubleshooting#cannot-find-modelname-with-id12345
  after_commit :send_notifications,
    if: -> { previous_changes.has_key?('status') || previous_changes.has_key?('created_at') },
    on: [:update, :create]

  def total_running_time
    if completed_at = test_jobs.maximum(:completed_at)
      completed_at -
        test_jobs.minimum("sent_at + (INTERVAL '1 seconds' * ROUND(worker_in_queue_seconds))")
    end
  end

  def serialized_run
    ActiveModelSerializers::SerializableResource.new(
      self, serializer: InternalTestRunsSerializer).serializable_hash
  end

  def status
    TestStatus.new(read_attribute(:status))
  end

  # Check for the current status in database
  # If something/someone cancelled the test_run while in memory,
  # we want to skip some actions to avoid setting the status back to non-cancelled.
  def db_status_is_cancelled?
    TestRun.where(id: id).limit(1).pluck(:status).first == TestStatus::CANCELLED
  end

  def update_status
    previous_status_code = status.code
    db_return = ActiveRecord::Base.connection.execute <<-SQL
      SELECT COALESCE (
        CASE array_length(sub.status, 1)
        WHEN 1 THEN status[1]
        ELSE ( CASE WHEN #{TestStatus::CANCELLED} = ANY(sub.status) THEN #{TestStatus::CANCELLED}
                    WHEN #{TestStatus::QUEUED} = ANY(sub.status) THEN #{TestStatus::RUNNING}
                    WHEN #{TestStatus::RUNNING} = ANY(sub.status) THEN #{TestStatus::RUNNING}
                    WHEN #{TestStatus::ERROR} = ANY(sub.status) THEN #{TestStatus::ERROR}
                    ELSE #{TestStatus::FAILED} END )
        END, 0)
      FROM (
        SELECT uniq(array_agg(status)) status
        FROM test_jobs
        WHERE test_run_id = #{id}
        GROUP BY test_run_id) sub
    SQL

    # http://www.rubydoc.info/gems/pg/0.17.1/PG%2FResult%3Avalues
    new_status_code = db_return.values.flatten[0].to_i

    # we intentionally check both in order to return true or false
    previous_status_code != new_status_code && self.status = new_status_code
  end

  # https://trello.com/c/ITi9lURr/127
  # https://trello.com/c/pDr9CgT9/128
  def retry?
    ![TestStatus::SETUP, TestStatus::QUEUED, TestStatus::RUNNING,
      TestStatus::CANCELLED].include?(read_attribute(:status))
  end

  # For the SHAs in sha_history, this method returns the first matching TestRun.
  # This is the most relevant commit we have already run so it will be used
  # as a statistic for TestJob costs.
  def previous_run
    runs = project.test_runs.terminal_status.where(commit_sha: sha_history)
    runs = runs.where("test_runs.id != ?", self.id) if self.id

    # TODO check if the array in sort_by works
    runs.sort_by{|test_run| [sha_history.index(test_run.commit_sha), -test_run.created_at.to_i] }.first
  end

  # Return the previous_run or the last TestRun on the same project if no
  # previous_run could be found
  def most_relevant_run
    return @most_relevant_run if @most_relevant_run

    @most_relevant_run = previous_run

    unless @most_relevant_run
      runs = project.test_runs.terminal_status
      runs = runs.where("test_runs.id != ?", self.id) if self.id

      @most_relevant_run = runs.order("created_at DESC").first
    end

    @most_relevant_run
  end

  def self.test_job_statuses(ids=[])
    sql = select("test_run_id id, "\
        "SUM( CASE test_jobs.status WHEN #{TestStatus::FAILED} THEN 1 ELSE 0 END) danger, "\
        "SUM( CASE test_jobs.status WHEN #{TestStatus::ERROR} THEN 1 ELSE 0 END) pink, "\
        "SUM( CASE test_jobs.status WHEN #{TestStatus::PASSED} THEN 1 ELSE 0 END) success, "\
        "COUNT(test_jobs.id) total").joins(:test_jobs).group(:test_run_id)
    sql = sql.where(id: ids) if ids.any?

    sql.map { |t| [t.id, t.attributes.reject! { |k| k == 'id' }] }.to_h
  end

  def branch_previous_terminal_status
    return nil unless tracked_branch.present?

    tracked_branch.test_runs.where("created_at < ?", self.created_at).
      where(status: [TestStatus::FAILED, TestStatus::PASSED, TestStatus::ERROR]).
      order("created_at DESC").limit(1).pluck(:status).first
  end

  # This method returns and Array of users which need to be notified based on
  # the old_status, current_status of a TestRun and the Notification settings
  # of each user.
  # Users have 2 sets of settings, the branch-based and the initiator-based.
  # For example they can define when to receive a notification for "master"
  # branch. They can also define when to receive a notification for the
  # other member's Builds. E.g.
  # "master" -> "After every failure"
  # "my builds" -> "When status changes"
  # "other people builds" -> "Never"
  # etc
  def notifiable_users(old_status, new_status)
    branch_based_notifiable_users =
      if tracked_branch
        previous_status = branch_previous_terminal_status
        tracked_branch.notifiable_users(previous_status, new_status)
      else
        []
      end

    initiator_based_notifiable_users = []
    if initiator
      # We assume the initiator is also a member of the project
      member_participations = project.project_participations.
        includes(:user).each do |participation|

        if participation.user == initiator
          setting = participation.my_builds_notify_on
        else
          setting = participation.others_builds_notify_on
        end

        case BranchNotificationSetting::NOTIFY_ON_MAP[setting]
        when :always
          initiator_based_notifiable_users << participation.user
        when :every_failure
          if [TestStatus::FAILED, TestStatus::ERROR].include?(new_status)
            initiator_based_notifiable_users << participation.user
          end
        end
      end
    end

    branch_based_notifiable_users | initiator_based_notifiable_users
  end

  private

  def copy_errors(errors)
    errors.to_hash.each do |key, value|
      value.each do |message|
        self.errors.add(key, message)
      end
    end
  end

  def last_file_run
    test_jobs.reject { |j| j.completed_at.nil? }.sort_by(&:completed_at).last
  end

  def failed?
    test_jobs.any? { |job| job.status.failed? }
  end

  def set_run_index
    return nil if run_index.present?

    if tracked_branch.blank?
      return nil if project.nil?

      self.run_index = (project.test_runs.where(tracked_branch: nil).
                        maximum(:run_index) || 0) + 1
    else
      self.run_index = (tracked_branch.test_runs.maximum(:run_index) || 0) + 1
    end
  end

  def cancel_test_jobs
    test_jobs.each do |tj|
      tj.update_attribute(:status, TestStatus::CANCELLED)
    end
  end

  def cancel_queued_runs_of_same_branch
    TestJob.joins(:test_run).where(
      status: [TestStatus::QUEUED, TestStatus::RUNNING],
      test_runs: { status: TestStatus::QUEUED,
        tracked_branch_id: tracked_branch.id
    }).update_all(status: TestStatus::CANCELLED)
    TestRun.where(status: [TestStatus::QUEUED, TestStatus::SETUP]).
      where(tracked_branch_id: tracked_branch.id).each do |tr|
        tr.update_attribute(:status, TestStatus::CANCELLED)
      end
  end

  # Send notifications either on creation or on status change.
  def send_notifications
    if previous_changes.has_key?('created_at')
      Broadcaster.publish("Project##{project_id}#TestRun#create",
        { event: 'TestRunCreate', test_run: serialized_run })
    else
      Broadcaster.publish(redis_live_update_resource_key,
        { event: 'TestRunUpdate', test_run: serialized_run })
    end
    VcsStatusNotifier.perform_later(id)

    old_status = previous_changes[:status] || status.code
    TestRunStatusEmailNotificationService.new(id, old_status, status.code).schedule_notifications

    true
  end
end
