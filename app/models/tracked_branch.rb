class TrackedBranch < ActiveRecord::Base
  OLD_RUNS_LIMIT = 20

  belongs_to :project, inverse_of: :tracked_branches
  has_many :test_runs, dependent: :destroy
  has_many :branch_notification_settings, dependent: :destroy

  # TODO : Write tests for this validation
  validates :branch_name, uniqueness: { scope: :project_id }

  after_create :create_branch_notification_settings

  delegate :status, :total_running_time, :commit_sha, to: :last_run,
    allow_nil: true

  def self.cleanup_old_runs
    # TODO:
    # This query is going to become heavy at some point in time.
    # In order to easy the pain, we can add a cleanup hook on the
    # after_create of TestRuns.
    branches_to_cleanup = TrackedBranch.joins(:test_runs).
      group("tracked_branches.id").having("COUNT(*) > #{OLD_RUNS_LIMIT}")

    branches_to_cleanup.find_each do |tracked_branch|
      tracked_branch.cleanup_old_runs
    end
  end

  def cleanup_old_runs
    test_runs_to_delete_count = test_runs.count - OLD_RUNS_LIMIT
    if test_runs_to_delete_count > 0
      test_runs.order("created_at ASC").
        limit(test_runs_to_delete_count).destroy_all
    end
  end

  def last_run
    test_runs.sort_by(&:created_at).last
  end

  def notifiable_users(old_status, new_status)
    flag_map = BranchNotificationSetting::NOTIFY_ON_MAP.invert
    flags_to_notify = [flag_map[:always]]

    if [TestStatus::FAILED, TestStatus::ERROR].include?(new_status)
      flags_to_notify << flag_map[:every_failure]
    end

    if old_status != new_status
      flags_to_notify << flag_map[:status_change]
    end

    branch_notification_settings.where(notify_on: flags_to_notify).map do |bns|
      bns.user
    end
  end

  private

  def create_branch_notification_settings
    project.project_participations.each do |participation|
      self.branch_notification_settings.create!(
        project_participation: participation,
        notify_on: participation.new_branch_notify_on)
    end
  end
end
