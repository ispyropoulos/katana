class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :github
  skip_filter :set_redirect_url_in_cookie
  before_filter :verify_request_from_github!

  def github
    # We listen for 'push' and 'delete' events
    # https://developer.github.com/v3/repos/hooks/#webhook-headers
    if request.headers['HTTP_X_GITHUB_EVENT'] == 'delete' &&
      params[:ref_type] == 'branch'
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
    elsif request.headers['HTTP_X_GITHUB_EVENT'] == 'push' &&
      params[:head_commit].present?
      repository_id = params[:repository][:id]
      projects = Project.where(repository_provider: 'github',
        repository_id: repository_id)
      projects.each do |project|
        branch_name = params[:ref].split('/').last
        if (tracked_branch = project.tracked_branches.find_by_branch_name(branch_name))
          tracked_branch.test_jobs.create!(commit_sha: params[:head_commit][:id])
        end
      end
    end

    head :ok
  end

  private
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
