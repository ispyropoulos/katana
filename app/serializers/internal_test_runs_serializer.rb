class InternalTestRunsSerializer < ActiveModel::Serializer
  include Rails.application.routes.url_helpers
  # In order to call distance_of_time_in_words
  include ActionView::Helpers::DateHelper
  attributes :id, :status_text, :status_css_class,
    :retry_url, :total_running_time, :html_class, :cancel_url,
    :statuses, :test_run_link, :commit_message, :commit_info,
    :show_retry

  def status_text
    object.status.text
  end

  def status_css_class
    object.status.css_class
  end

  def total_running_time
    distance_of_time_in_words(0, object.total_running_time,
                              include_seconds: true)
  end

  def retry_url
    retry_project_test_run_path(object.project, object)
  end

  def cancel_url
    project_test_run_path(object.project, object, status: TestStatus::CANCELLED)
  end

  def html_class
    TestStatus::STATUS_CLASS_MAP[object.status.code]
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

  def show_retry
    object.status.code != TestStatus::RUNNING
  end
end
