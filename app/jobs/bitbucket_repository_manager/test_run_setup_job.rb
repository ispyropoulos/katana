class BitbucketRepositoryManager::TestRunSetupJob < ActiveJob::Base
  queue_as :default

  def perform(test_run_or_id)
    test_run = if test_run_or_id.is_a?(TestRun)
                 test_run_or_id
               else
                 TestRun.find(test_run_or_id)
               end

    BitbucketRepositoryManager.new({project: test_run.project}).
      setup_test_run(test_run)
  end
end
