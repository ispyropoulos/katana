class GithubStatusNotificationService
  include Rails.application.routes.url_helpers
  # https://developer.github.com/v3/repos/statuses/

   GITHUB_STATUS_MAP =
     { 'Failed' => 'failure',
       'Queued' => 'pending',
       'Running' => 'pending',
       'Error' => 'error',
       'Cancelled' => 'error',
       'Passed' => 'success' }

   GITHUB_DESCRIPTION_MAP =
     { 'Failed' => 'Some specs are failing.',
       'Queued' => 'Build is going to be testributed soon.',
       'Running' => 'Build is being testributed.',
       'Error' => 'There are some errors in your build.',
       'Cancelled' => 'Your build has been cancelled.',
       'Passed' => 'All checks have passed!' }

  def initialize(test_run)
    @test_run = test_run
  end

  def publish
    # POST /repos/:owner/:repo/statuses/:sha
    # http://www.rubydoc.info/github/octokit/octokit.rb/Octokit%2FClient%2FStatuses%3Acreate_status
    # create_status(repo, sha, state, options = {})

    project = @test_run.project
    client = project.user.github_client
    description = to_github_description(@test_run.status.text)
    options = { context: 'testributor.com',
                target_url: project_test_run_url(project_id: project.id, id: @test_run.id),
                description: description }
    status = to_github_status(@test_run.status.text)

    client.create_status(project.repository_id, @test_run.commit_sha, status, options)
  end

  private

  def to_github_status(status)
    GITHUB_STATUS_MAP[status]
  end

  def to_github_description(status)
    GITHUB_DESCRIPTION_MAP[status]
  end
end
