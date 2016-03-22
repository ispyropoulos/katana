class DashboardController < ApplicationController
  layout "dashboard"
  before_filter :authenticate_user!
  # Skip setting the redirect_url in cookies in order to avoid redirecting the
  # user to this intermediate warning page, after returning from the provider's
  # authorization flow.
  skip_before_filter :set_redirect_url_in_cookie,
    only: [:github_authorization_required, :bitbucket_authorization_required]

  rescue_from Octokit::Unauthorized do |exception|
    if request.xhr?
      render json: { redirect_path: github_authorization_required_dashboard_path }
    else
      render action: :github_authorization_required
    end
  end

  rescue_from BitBucket::Error::Unauthorized do |exception|
    if request.xhr?
      render json: {redirect_path: bitbucket_authorization_required_dashboard_path }
    else
      render action: :bitbucket_authorization_required
    end
  end

  def index
    @projects = current_user.participating_projects.
      includes(tracked_branches: { test_runs: :test_jobs }).
      order(:repository_owner, :name)

    if @projects.empty?
      redirect_to project_wizard_path(:choose_provider)
    end
  end

  def current_ability
    @current_ability ||= Ability.new(current_user, current_project)
  end

  def github_authorization_required; end

  def bitbucket_authorization_required; end
end
