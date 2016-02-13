class TestRunObserver < ActiveRecord::Observer
  def after_save(test_run)
    VcsStatusNotifier.perform_later(test_run.id) if test_run.status_changed?
  end

  def after_create(test_run)
    VcsStatusNotifier.perform_later(test_run.id) if test_run.status_changed?
  end
end
