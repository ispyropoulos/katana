class InternalTestRunsSerializer < ActiveModel::Serializer
  include Models::HasRunningTime
  include Models::HasStatus
  include Rails.application.routes.url_helpers

  attributes :id, :run_index, :status_text, :status_css_class, :unsuccessful,
    :retry_url, :total_running_time, :html_class, :cancel_url,
    :statuses, :test_run_link, :commit_message, :commit_info,
    :terminal_status, :url

  def url
    # TODO: Do not hardcode url
    project_test_run_url(object.project, object, host: Rails.configuration.action_mailer.asset_host)
  end

  def retry_url
    retry_project_test_run_path(object.project, object)
  end

  def cancel_url
    project_test_run_path(object.project, object, status: TestStatus::CANCELLED)
  end

  def statuses
    TestRun.test_job_statuses([object.id])[object.id]
  end

  def test_run_link
    project_test_run_path(object.project, object)
  end

  def commit_message
    object.decorate.commit_message
  end

  def commit_info
    object.decorate.commit_info
  end

  def terminal_status
    object.status.terminal?
  end
end
