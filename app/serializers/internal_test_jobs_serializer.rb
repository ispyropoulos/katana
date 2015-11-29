class InternalTestJobsSerializer < ActiveModel::Serializer
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::DateHelper
  attributes :command, :id, :status_text,
    :status_css_class, :completed_at, :retry_url,
    :test_errors, :failures, :count, :assertions, :skips, :total_running_time


  # We serialise this attribute as seconds since epoch instead of Datetime to
  # allow easier parsing, as this travels via API calls between the server and
  # the workers. This value will eventually return back to the server (untouched)
  # and will be persisted as TestJob#sent_at [Datetime]. This timestamp helps in
  # making further time calculations and reports for the test suites.
  def sent_at_seconds_since_epoch
    Time.current.utc.to_i
  end

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

  def completed_at
    I18n.l(object.completed_at, format: :short) if object.completed_at?
  end

  def retry_url
    project_branch_test_run_test_job_path(object.test_run.tracked_branch.project,
                                          object.test_run.tracked_branch_id,
                                          object.test_run_id, object,
                                         status: TestStatus::QUEUED)
  end
end
