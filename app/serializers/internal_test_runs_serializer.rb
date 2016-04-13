class InternalTestRunsSerializer < ActiveModel::Serializer
  include Models::HasRunningTime
  include Models::HasStatus
  include Rails.application.routes.url_helpers

  attributes :id, :run_index, :status_text, :status_css_class, :unsuccessful,
    :retry_url, :total_running_time, :html_class, :cancel_url,
    :statuses, :test_run_link, :commit_message, :branch_id,
    :terminal_status, :commit_author, :commit_timestamp, :commit_time_ago,
    :can_be_retried, :can_be_cancelled, :is_running, :commit_info

  def retry_url
    retry_project_test_run_path(object.project_id, object)
  end

  def cancel_url
    project_test_run_path(object.project_id, object, status: TestStatus::CANCELLED)
  end

  def statuses
    test_job_stats = TestRun.test_job_statuses([object.id])[object.id]

    # if TestRun is setting up or it has an error which did not allow
    # it to create TestJobs we assign 0 to every attribute
    test_job_stats ||= { success: 0, total: 0, pink: 0, danger: 0 }
  end

  def test_run_link
    project_test_run_path(object.project_id, object)
  end

  def commit_message
    decorated_object.commit_message
  end

  def commit_author
    decorated_object.commit_author
  end

  def commit_time_ago
    decorated_object.commit_time_ago
  end

  def commit_timestamp
    decorated_object.decorated_commit_timestamp
  end

  def terminal_status
    object.status.terminal?
  end

  def branch_id
    object.tracked_branch_id
  end

  def can_be_retried
    object.status.can_be_retried?
  end

  def can_be_cancelled
    object.status.can_be_cancelled?
  end

  def is_running
    object.status.code == TestStatus::RUNNING
  end

  def decorated_object
    object.decorate
  end

  def commit_info
    decorated_object.commit_info
  end
end
