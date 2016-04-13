class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_filter :set_redirect_url_in_cookie
  before_filter :exception_notification_additional_data

  layout 'application_layout'

  helper_method :current_project

  # When project_id is set in params, set current_project if current_user
  # is a participant. If project is specified with a different name
  # (as in ProjectsController with :id), this method should be overridden.
  def current_project(param_name=:project_id)
    return @current_project if @current_project
    return nil unless params[param_name]

    if current_user
      @current_project = current_user.participating_projects.find_by(id: params[param_name])
    end
    # If no project is found yet, try the public projects
    @current_project ||= Project.non_private.find_by(id: params[param_name])
  end

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end

  protected

  def set_redirect_url_in_cookie
    cookies[:redirect_to_url] = request.url
  end

  def exception_notification_additional_data
    # add here whatever you like to be displayed at the data section
    # of your exception notifications

    request.env["exception_notifier.exception_data"] = {
      :params => params
    }
  end
end
