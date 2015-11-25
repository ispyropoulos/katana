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
    case @code
    when CANCELLED
      'label label-default'
    when QUEUED
      'label label-info'
    when RUNNING
      'label label-primary running'
    when PASSED
      'label label-success'
    when FAILED
      'label label-danger'
    when ERROR
      'label label-pink'
    end
  end

  def button_css_class
    case @code
    when CANCELLED || FAILED || ERROR
      'btn btn-success'
    when QUEUED || RUNNING
      'btn btn-danger'
    end
  end

  def terminal?
    @code.in? [ERROR, FAILED, PASSED]
  end
end
