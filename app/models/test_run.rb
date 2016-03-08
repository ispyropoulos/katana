class TestRun < ActiveRecord::Base
  # For redis_live_update_resource_key
  include Models::RedisLiveUpdates
  belongs_to :tracked_branch
  belongs_to :project
  has_many :test_jobs, dependent: :delete_all, inverse_of: :test_run

  delegate :completed_at, to: :last_file_run, allow_nil: true

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
    if: ->{ run_index.nil? && tracked_branch.present? }
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
    ActiveModel::SerializableResource.new(
      self, serializer: InternalTestRunsSerializer).serializable_hash
  end

  def status
    TestStatus.new(read_attribute(:status))
  end

  # This method returns all filenames for this repo and ref from github.
  # TODO: Github limit is something like 1000 files per request.
  # Refactor this method so that it always returns all filenames no matter
  # how many (or find some better solution).
  def project_file_names
    repo = tracked_branch.project.repository_id
    github_client.tree(repo, commit_sha, recursive: true)[:tree].map(&:path)
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
        "SUM( CASE test_jobs.status WHEN 3 THEN 1 ELSE 0 END) danger, "\
        "SUM( CASE test_jobs.status WHEN 4 THEN 1 ELSE 0 END) pink, "\
        "SUM( CASE test_jobs.status WHEN 2 THEN 1 ELSE 0 END) success, "\
        "COUNT(test_jobs.id) length").joins(:test_jobs).group(:test_run_id)
    sql = sql.where(id: ids) if ids.any?

    sql.map { |t| [t.id, t.attributes.reject! { |k| k == 'id' }] }.to_h
  end

  def branch_previous_terminal_status
    tracked_branch.test_runs.where("created_at < ?", self.created_at).
      where(status: [TestStatus::FAILED, TestStatus::PASSED, TestStatus::ERROR]).
      order("created_at DESC").limit(1).pluck(:status).first
  end

  private

  # TODO: this almost the same as ProjectWizard#copy_errors. DRY
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

  def github_client
    tracked_branch.project.user.github_client
  end

  def failed?
    test_jobs.any? { |job| job.status.failed? }
  end

  def set_run_index
    return nil if run_index.present? || tracked_branch.blank?

    self.run_index = (tracked_branch.test_runs.maximum(:run_index) || 0) + 1
  end

  def cancel_test_jobs
    test_jobs.update_all(status: TestStatus::CANCELLED)
  end

  def cancel_queued_runs_of_same_branch
    TestJob.joins(:test_run).where(
      status: [TestStatus::QUEUED, TestStatus::RUNNING],
      test_runs: { status: TestStatus::QUEUED,
        tracked_branch_id: tracked_branch.id
    }).update_all(status: TestStatus::CANCELLED)
    TestRun.queued.where(tracked_branch_id: tracked_branch.id).
      update_all(status: TestStatus::CANCELLED)
  end

  def send_notifications
    VcsStatusNotifier.perform_later(id)

    old_status = previous_changes[:status] || status.code
    TestRunStatusEmailNotificationService.new(id, old_status, status.code).schedule_notifications

    true
  end
end
