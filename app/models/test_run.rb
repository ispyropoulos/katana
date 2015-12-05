class TestRun < ActiveRecord::Base
  # For redis_live_update_resource_key
  include Models::RedisLiveUpdates
  belongs_to :tracked_branch
  has_one :project, through: :tracked_branch
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

  after_save :cancel_test_jobs,
    if: ->{ status_changed? && self[:status] == TestStatus::CANCELLED }

  before_create :cancel_queued_runs_of_same_branch

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

  # Example yml file:
  # each:
  #   pattern: 'test/*/**_test.rb'
  #   command: 'bin/rake test %{file}'
  #   before: 'some_command'
  # javascript:
  #   command: 'bin/rake test_javascript'
  #   after: "some_cleanup_command"
  #
  # We assume that the JOBS_YML_PATH exists and has valid commands.
  # @raise JOBS_YML_PATH not found if it doesn't exist
  # @returns false if JOBS_YML_PATH is invalid?
  # @raises "JOBS_YML_PATH not found" if JOBS_YML_PATH doesn't exist?
  # if JOBS_YML_PATH is invalid, then the JOBS_YML_PATH errors are copied
  # to self. As a result, self.errors can be used to display errors to the user
  def build_test_jobs
    yml_contents = jobs_yml
    raise "#{ProjectFile::JOBS_YML_PATH} not found" unless yml_contents
    testributor_yml = ProjectFile.new(path: ProjectFile::JOBS_YML_PATH,
                                      contents: yml_contents)
    if testributor_yml.invalid?
      copy_errors(testributor_yml.errors)
      return false
    end

    jobs_description = YAML.load(yml_contents)

    if each_description = jobs_description.delete("each")
      pattern = each_description["pattern"]
      command = each_description["command"]
      before = each_description["before"].to_s
      after = each_description["after"].to_s

      file_names = project_file_names
      file_names.select{|f| f.match(pattern)}.each do |f|
        test_jobs.build(
          command: command.gsub(/%{file}/, f), before: before, after: after)
      end
    end

    jobs_description.each do |job_name, description|
      command = description["command"]
      before = description["before"].to_s
      after = description["after"].to_s
      test_jobs.build(command: command, before: before, after: after)
    end
    Katanomeas.new(self).assign_chunk_indexes_to_test_jobs

    true
  end

  # Returns the content of ProjectFile::JOBS_YML_PATH file. The file can either be defined
  # in Project's files (project_files association) or it can be checked in the
  # git repository. If defined both ways the repo version wins to let the users
  # use a customized file in specific branches (e.g. if they don't want to run
  # all tests on some feature branch they can commit this file to override the
  # global project configuration).
  def jobs_yml
    file = nil

    if github_client.present?
      repo = project.repository_id
      file =
        begin
          file =
            github_client.contents(repo, path: ProjectFile::JOBS_YML_PATH, ref: commit_sha)

          Base64.decode64(file.content)
        rescue Octokit::NotFound
          nil
        end
    end

    if file.blank?
      file =
        project.project_files.where(path: ProjectFile::JOBS_YML_PATH).first.try(:contents)
    end

    file
  end

  # This method returns all filenames for this repo and ref from github.
  # TODO: Github limit is something like 1000 files per request.
  # Refactor this method so that it always returns all filenames no matter
  # how many (or find some better solution).
  def project_file_names
    repo = tracked_branch.project.repository_id
    github_client.tree(repo, commit_sha, recursive: true)[:tree].map(&:path)
  end

  def failing?
    ([TestStatus::FAILED, TestStatus::ERROR] & test_jobs.pluck(:status)).any?
  end

  def update_status!
    ActiveRecord::Base.connection.execute <<-SQL
      UPDATE test_runs SET status = (
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
          GROUP BY test_run_id) sub)
        WHERE test_runs.id = #{id}
    SQL
  end

  # https://trello.com/c/ITi9lURr/127
  # https://trello.com/c/pDr9CgT9/128
  def retry?
    ![TestStatus::QUEUED, TestStatus::RUNNING, TestStatus::CANCELLED].include?(
      read_attribute(:status))
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
    test_jobs.where('completed_at IS NOT NULL').sort_by(&:completed_at).last
  end

  def github_client
    tracked_branch.project.user.github_client
  end

  def failed?
    test_jobs.any? { |job| job.status.failed? }
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
end
