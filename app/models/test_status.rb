class TestStatus
  attr_reader :code
  QUEUED = 0
  RUNNING = 1
  PASSED = 2
  FAILED = 3
  ERROR = 4
  CANCELLED = 5

  STATUS_MAP = {
    QUEUED => 'Queued',
    RUNNING => 'Running',
    PASSED => "Passed",
    FAILED => 'Failed',
    ERROR => 'Error',
    CANCELLED => 'Cancelled'
  }

  STATUS_CLASS_MAP = {
    CANCELLED => 'default',
    QUEUED => 'info',
    RUNNING => 'primary',
    PASSED => 'success',
    FAILED => 'danger',
    ERROR => 'pink'
  }

  def initialize(code)
    @code = code
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
    when QUEUED, RUNNING
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
    when @code.in?([QUEUED, RUNNING])
      'btn btn-primary'
    end
  end

  def terminal?
    @code.in? [ERROR, FAILED, PASSED]
  end
end
