class RepositoryManager::TestRunSetupJob < ActiveJob::Base
  queue_as :default

  def perform(test_run_id)
    test_run = TestRun.find(test_run_id)

    case test_run.project.repository_provider
    when "github"
      GithubRepositoryManager::TestRunSetupJob.perform_now(test_run)
    when "bitbucket"
      BitbucketRepositoryManager::TestRunSetupJob.perform_now(test_run)
    else
      raise "Unknown repository provider"
    end
  end
end
