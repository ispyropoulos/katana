class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:github, :bitbucket]
  skip_filter :set_redirect_url_in_cookie
  before_filter :verify_request_from_github!, only: :github

  def github
    # We listen for 'push' and 'delete' events
    # https://developer.github.com/v3/repos/hooks/#webhook-headers
    if request.headers['HTTP_X_GITHUB_EVENT'] == 'delete' &&
      params[:ref_type] == 'branch'
      handle_github_branch_deletion
    elsif request.headers['HTTP_X_GITHUB_EVENT'] == 'push' &&
      params[:head_commit].present?
      handle_github_push
    end

    head :ok
  end

  def bitbucket
    # We listen for 'push' events
    # https://confluence.atlassian.com/display/bitbucket/event+payloads
    if request.headers['X-Event-Key'] == 'repo:push'
      handle_bitbucket_push
    end

    head :ok
  end

  private

  def handle_github_push
    repository_id = params[:repository][:id]
    project = Project.where(repository_provider: 'github',
      repository_id: repository_id).take
    branch_name = params[:ref].split('/').last

    if (tracked_branch = project.tracked_branches.find_by_branch_name(branch_name))
      manager = RepositoryManager.new(project)
      head_commit = params[:head_commit]

      manager.create_test_run!({
        commit_sha:                head_commit[:id],
        commit_message:            head_commit[:message],
        commit_timestamp:          head_commit[:timestamp],
        commit_url:                head_commit[:url],
        commit_author_name:        head_commit[:author][:name],
        commit_author_email:       head_commit[:author][:email],
        commit_author_username:    head_commit[:author][:username],
        commit_committer_name:     head_commit[:committer][:name],
        commit_committer_email:    head_commit[:committer][:email],
        commit_committer_username: head_commit[:committer][:username],
        tracked_branch_id:         tracked_branch.id,
      })
    end
  end

  def handle_bitbucket_push
    repository_slug = params[:repository][:name].downcase
    project = Project.where(repository_provider: 'bitbucket',
      repository_slug: repository_slug).take
    branch_name = params[:push][:changes].first[:new][:name]

    if (tracked_branch = project.tracked_branches.find_by_branch_name(branch_name))
      manager = RepositoryManager.new(project)
      head_commit = params[:push][:changes].first[:new][:target]

      manager.create_test_run!({
        commit_sha:        head_commit[:hash],
        commit_message:    head_commit[:message],
        commit_timestamp:  head_commit[:date],
        commit_url:        head_commit[:links][:html][:href],
        tracked_branch_id: tracked_branch.id,
      })
    end
  end

  def handle_github_branch_deletion
    repository_id = params[:repository][:id]
    branch_name = params[:ref]
    # TODO Do any pre-branch removal tasks
    projects = Project.where(repository_provider: 'github',
      repository_id: repository_id)
    projects.each do |project|
      if (tracked_branch = project.tracked_branches.find_by_branch_name(branch_name))
        tracked_branch.destroy!
      end
    end
  end

  def verify_request_from_github!(request_body=request.body.read)
    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha1'),
      ENV['GITHUB_WEBHOOK_SECRET'],
      request_body
    )
    unless Rack::Utils.secure_compare(signature, request.headers['HTTP_X_HUB_SIGNATURE'])
      head :unauthorized
    end
  end
end
