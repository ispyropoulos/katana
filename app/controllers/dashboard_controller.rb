class DashboardController < ApplicationController
  before_filter :authenticate_user!
  before_filter :check_for_active_providers, except: [:create, :destroy]

  def show

  end

  protected
  def check_for_active_providers
    unless current_user.github_access_token.blank? || current_user.github_client
      flash.now[:alert] =
        "Your Testributor account is not connected to GitHub anymore. "\
        "Please #{view_context.link_to 're-connect', view_context.github_oauth_authorize_url}.".
          html_safe
    end
  end
end
