class VcsStatusNotifier < ActiveJob::Base
  queue_as :default

  def perform(test_run_id)
    test_run = TestRun.find(test_run_id)

    manager = RepositoryManager.new({ project: test_run.project }).
      publish_status_notification(test_run)
  end
end
