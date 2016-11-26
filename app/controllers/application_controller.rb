class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :set_redirect_url_in_cookie
  before_action :exception_notification_additional_data

  layout :choose_layout

  helper_method :current_project

  # When project_id is set in params, set current_project if current_user
  # is a participant. If project is specified with a different name
  # (as in ProjectsController with :id), this method should be overridden.
  def current_project(param_name=:project_id)
    return @current_project if @current_project
    return nil unless params[param_name]

    if current_user
      @current_project = current_user.participating_projects.includes(:members).
        find_by(id: params[param_name])
    end
    # If no project is found yet, try the public projects
    @current_project ||= Project.non_private.includes(:members).
      find_by(id: params[param_name])
  end

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end

  rescue_from CanCan::AccessDenied do |exception|
    render 'errors/access_denied', status: 403, layout: 'bare'
  end

  def redirect_back_fallback_path
    "/"
  end

  protected

  def set_redirect_url_in_cookie
    # We cannot redirect to "POST" urls so we only set this when the request is
    # "GET".
    cookies[:redirect_to_url] = request.url if request.method == "GET"
  end

  def exception_notification_additional_data
    # add here whatever you like to be displayed at the data section
    # of your exception notifications

    request.env["exception_notifier.exception_data"] = {
      :params => params
    }
  end

  private

  def choose_layout
    user_signed_in? ? 'dashboard' : 'bare'
  end

end
