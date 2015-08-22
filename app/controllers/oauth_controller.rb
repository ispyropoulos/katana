class OauthController < ApplicationController
  before_filter :authenticate_user!
  skip_filter :set_redirect_url_in_cookie

  def github_callback
    begin
      response = Octokit.exchange_code_for_token(params[:code])
    rescue Octokit::Error => e
      # TODO Replace with a friendly message and send exception to admins
      redirect_to dashboard_path, alert: e.message and return
    end
    current_user.update_attributes!(github_access_token: response.access_token)

    redirect_to cookies[:redirect_to_url],
      notice: 'We can now access your GitHub repos. Thanks!'
  end
end
