class TestStatus
  attr_reader :code

  SETUP     = 0 # Doesn't have test jobs yet
  QUEUED    = 1 # Has TestJobs, chunked, waiting to be sent to workers
  RUNNING   = 2 # At least on TestJob is already sent to a worker
  PASSED    = 3 # All TestJobs are PASSED
  FAILED    = 4 # At least one TestJob is FAILED and none is ERROR
  ERROR     = 5 # At least one TestJob is ERROR
  CANCELLED = 6 # TestRun is CANCELLED. All TestJobs are CANCELLED

  STATUS_MAP = {
    SETUP     => 'Setup',
    QUEUED    => 'Queued',
    RUNNING   => 'Running',
    PASSED    => 'Passed',
    FAILED    => 'Failed',
    ERROR     => 'Error',
    CANCELLED => 'Cancelled'
  }

  STATUS_CLASS_MAP = {
    SETUP     => 'info',
    QUEUED    => 'info',
    RUNNING   => 'primary',
    PASSED    => 'success',
    FAILED    => 'danger',
    ERROR     => 'pink',
    CANCELLED => 'default',
  }

  GITHUB_STATUS_MAP = {
    SETUP     => 'pending',
    QUEUED    => 'pending',
    RUNNING   => 'pending',
    PASSED    => 'success',
    FAILED    => 'failure',
    ERROR     => 'error',
    CANCELLED => 'error'
  }

  GITHUB_DESCRIPTION_MAP = {
    SETUP     => 'Build is going to be testributed soon.',
    QUEUED    => 'Build is going to be testributed soon.',
    RUNNING   => 'Build is being testributed.',
    PASSED    => 'All checks have passed!',
    FAILED    => 'Some specs are failing.',
    ERROR     => 'There are some errors in your build.',
    CANCELLED => 'Your build has been cancelled.'
  }

  def initialize(code)
    @code = code
  end

  def setup?
    @code == SETUP
  end

  def queued?
    @code == QUEUED
  end

  def running?
    @code == RUNNING
  end

  def passed?
    @code == PASSED
  end

  def failed?
    @code == FAILED
  end

  def error?
    @code == ERROR
  end

  def cancelled?
    @code == CANCELLED
  end

  def cta_text
    case @code
    when SETUP, QUEUED, RUNNING
      "Cancel"
    when ERROR, FAILED, PASSED
      "Retry"
    end
  end

  def status_to_set
    if cta_text == "Cancel"
      CANCELLED
    else
      QUEUED
    end
  end

  def text
    STATUS_MAP[@code]
  end

  def css_class
    "label label-#{STATUS_CLASS_MAP[@code]}"
  end

  def button_css_class
    case
    when @code.in?([CANCELLED, FAILED, ERROR])
      'btn btn-success'
    when @code.in?([SETUP, QUEUED, RUNNING])
      'btn btn-primary'
    end
  end

  def to_github_status
    GITHUB_STATUS_MAP[code]
  end

  def to_github_description
    GITHUB_DESCRIPTION_MAP[code]
  end

  def terminal?
    @code.in? [ERROR, FAILED, PASSED]
  end

  def unsuccessful?
    @code.in? [ERROR, FAILED]
  end
end
