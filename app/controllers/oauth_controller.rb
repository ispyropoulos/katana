class OauthController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :set_redirect_url_in_cookie
  include ApplicationHelper

  def github_callback
    begin
      response = Octokit.exchange_code_for_token(params[:code])
    rescue Octokit::Error => e
      # TODO Replace with a friendly message and send exception to admins
      redirect_to root_path, alert: e.message and return
    end
    # TODO: Store login attribute in user to avoid fetching from github each time user.login is called
    current_user.update_attributes!(github_access_token: response.access_token)

    redirect_to cookies[:redirect_to_url] || root_path,
      notice: 'We can now access your GitHub repositories.'
  end

  # The Ruby library we use for accessing the BitBucket API does not support
  # any of the OAuth1/OAuth2 authorisation flows. For this reason we do this
  # semi-manually, using the OAuth gem. We are using OAuth v1.
  def bitbucket_callback
    consumer = OAuth::Consumer.new(ENV['BITBUCKET_CLIENT_ID'],
      ENV['BITBUCKET_CLIENT_SECRET'], site: 'https://bitbucket.org',
      request_token_path: '/api/1.0/oauth/request_token',
      authorize_path: '/api/1.0/oauth/authenticate',
      access_token_path: '/api/1.0/oauth/access_token')

    request_token = OAuth::RequestToken.new(consumer, session[:request_token],
      session[:request_token_secret])

    access_token = request_token.get_access_token(
      oauth_verifier: params[:oauth_verifier])

    current_user.update_attributes!(
      bitbucket_access_token: access_token.token,
      bitbucket_access_token_secret: access_token.secret)

    redirect_to cookies[:redirect_to_url] || root_path,
      notice: 'We can now access your Bitbucket repositories.'
  end

  # This action simply redirects the user to the authorization url.
  # To generate the authorization url, a request to the provider must be sent.
  # To avoid making this request simply to show a link which the user might
  # not click, we only generate the authorization url when the user actually
  # clicks the link to this action.
  def authorize_bitbucket
    redirect_to bitbucket_oauth_authorize_url
  end
end
