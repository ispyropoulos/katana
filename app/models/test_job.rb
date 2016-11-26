# Time tracking related attribute legend
# --------------------------------------
# #sent_at                    - When the server submitted the job to the worker
# #worker_in_queue_seconds    - The number of seconds the job spent in the
#                               worker's queue
# #completed_at               - When the worker finished the job
# #reported_at                - When the server received the job results from
#                               the worker
# #worker_command_run_seconds - The number of seconds it took to run the job
#
class TestJob < ActiveRecord::Base

  # The smaller this number is, the less new runs will be needed to "balance"
  # the avg_worker_command_run_seconds.
  NUMBER_OF_SIGNIFICANT_RUNS = 3

  # For redis_live_update_resource_key
  include Models::RedisLiveUpdates
  belongs_to :test_run, inverse_of: :test_jobs
  validates :test_run, presence: true

  before_validation :set_completed_at
  # avg_worker_command_run_seconds is the cost prediction for the next runs
  # old_avg_worker_command_run_seconds is the cost prediction on which we based
  # the "chunking" for this run
  before_validation :set_old_avg_worker_command_run_seconds,
    if: ->{ new_record? }
  before_validation :set_avg_worker_command_run_seconds,
    if: ->{ worker_command_run_seconds_changed? }
  after_commit :update_test_run_status,
    if: -> { previous_changes.has_key?('status') || previous_changes.has_key?('created_at') },
    on: [:create, :update]

  scope :queued, -> { where(status: TestStatus::QUEUED) }
  scope :running, -> { where(status: TestStatus::RUNNING) }
  scope :passed, -> { where(status: TestStatus::PASSED) }
  scope :failed, -> { where(status: TestStatus::FAILED) }
  scope :error, -> { where(status: TestStatus::ERROR) }
  scope :cancelled, -> { where(status: TestStatus::CANCELLED) }

  def worker_uuid_short
    worker_uuid.to_s[0..7]
  end

  # Converts seconds since epoch to datetime
  # The UTC timestamp recorded when Katana sent this job to the worker,
  # expressed in seconds since epoch.
  def sent_at_seconds_since_epoch=(val)
    self.sent_at= Time.at(val.to_i).utc
  end

  def status
    TestStatus.new(read_attribute(:status))
  end

  # Returns the total time it took for a TestJob to run, from a user's
  # perspective. Therefore, we consider as total running time for a job the
  # duration between the point the job 'left' the server and the point that its
  # result was reported back, minus the time spent in the worker queue (as this
  # is considered 'waiting' time).
  #
  # @return [Integer]
  def total_running_time
    if reported_at && sent_at && worker_in_queue_seconds
      (reported_at - sent_at) - worker_in_queue_seconds
    end
  end

  def serialized_job
    ActiveModelSerializers::SerializableResource.new(
      self, serializer: InternalTestJobsSerializer).serializable_hash
  end

  def retry!
    self.result = ''
    self.status = TestStatus::QUEUED
    self.test_errors = 0
    self.failures = 0
    self.count = 0
    self.assertions = 0
    self.skips = 0
    self.worker_uuid = nil
    self.rerun = true
    save!
  end

  # test_run.most_relevant_run => matching command job
  # NOTE: Memoizes value (even when value is nil)
  def most_relevant_job
    if @most_relevant_job || @most_relevant_job_already_searched
      return @most_relevant_job
    end

    @most_relevant_job_already_searched = true
    unless (test_run && (most_relevant_run = test_run.most_relevant_run))
      return nil
    end

    @most_relevant_job =
      most_relevant_run.test_jobs.detect{|j| j.command == command}
  end

  # We store the cost prediction for this test job on
  # old_avg_worker_command_run_seconds column on new records.
  def set_old_avg_worker_command_run_seconds
    if old_avg_worker_command_run_seconds.nil? && most_relevant_job &&
      most_relevant_job.avg_worker_command_run_seconds.present?

      self.old_avg_worker_command_run_seconds =
        most_relevant_job.avg_worker_command_run_seconds
    end
  end

  private

  def set_completed_at
    if completed_at.nil? && sent_at && worker_in_queue_seconds && worker_command_run_seconds
      self.completed_at=
        sent_at + (worker_in_queue_seconds + worker_command_run_seconds).round.seconds
    end
  end

  # We store the cost prediction for the next runs on
  # avg_worker_command_run_seconds column when the worker_command_run_seconds
  # column is set. This is the old_avg_worker_command_run_seconds updated with
  # the actual cost of this job.
  def set_avg_worker_command_run_seconds
    cost_prediction =
      if avg_worker_command_run_seconds.present?
        avg_worker_command_run_seconds # use the existing if already set
      elsif old_avg_worker_command_run_seconds.present?
        old_avg_worker_command_run_seconds # use the old cost prediction if already set
      elsif most_relevant_job && most_relevant_job.avg_worker_command_run_seconds.present?
        # find the old prediction if not already set.
        # This should not happen since the set_old_avg_worker_command_run_seconds
        # hook is run first
        most_relevant_job.avg_worker_command_run_seconds
      end

    self.avg_worker_command_run_seconds =
      # update the prediction when the actual cost is available
      if cost_prediction.present? && worker_command_run_seconds.present?
          ((cost_prediction * NUMBER_OF_SIGNIFICANT_RUNS) +
            worker_command_run_seconds) / (NUMBER_OF_SIGNIFICANT_RUNS + 1).to_d
      elsif cost_prediction.present?
        cost_prediction # use the old prediction if worker_command_run_seconds is set to nil
      elsif worker_command_run_seconds.present?
        worker_command_run_seconds # use the actual cost if no prediction exists
      end
  end

  def update_test_run_status
    test_run.update_status && test_run.save!
    Broadcaster.publish(test_run.redis_live_update_resource_key,
      { test_job: serialized_job,
        event: 'TestJobUpdate' })
    Broadcaster.publish(test_run.redis_live_update_resource_key,
      { test_run: test_run.serialized_run,
        event: 'TestRunUpdate' })

    true # don't break callback chain
  end
end
