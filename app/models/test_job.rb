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
  belongs_to :test_run

  validates :test_run, presence: true

  before_validation :set_completed_at
  after_save :update_test_run_status

  scope :queued, -> { where(status: TestStatus::QUEUED) }
  scope :running, -> { where(status: TestStatus::RUNNING) }
  scope :passed, -> { where(status: TestStatus::PASSED) }
  scope :failed, -> { where(status: TestStatus::FAILED) }
  scope :error, -> { where(status: TestStatus::ERROR) }
  scope :cancelled, -> { where(status: TestStatus::CANCELLED) }

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
    ActiveModel::SerializableResource.new(
      self, serializer: InternalTestJobsSerializer).serializable_hash
  end

  private
  def set_completed_at
    if completed_at.nil? && sent_at && worker_in_queue_seconds && worker_command_run_seconds
      self.completed_at=
        sent_at + (worker_in_queue_seconds + worker_command_run_seconds).round.seconds
    end
  end

  def update_test_run_status
    test_run.update_status!
  end
end
