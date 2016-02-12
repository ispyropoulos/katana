class VcsStatusNotifier < ActiveJob::Base
  queue_as :default

  def perform(test_run_id)
    test_run = TestRun.find(test_run_id)

    GithubStatusNotificationService.new(test_run).publish
  end
end
