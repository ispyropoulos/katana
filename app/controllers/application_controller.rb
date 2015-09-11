class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  helper_method :current_organization

  def current_organization
    return false unless current_user

    return @current_organization if @current_organization

    if (organization_id = cookies.permanent.signed[:organization])
      @current_organization =
        current_user.organizations.select{|o| o.id == organization_id }.first
    end

    if @current_organization.nil?
      @current_organization = current_user.organizations.first ||
        current_user.participating_organizations.first
    end

    if @current_organization
      cookies.signed[:organization] = @current_organization.id
    end

    @current_organization
  end
end
