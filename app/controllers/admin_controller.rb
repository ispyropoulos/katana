class AdminController < ApplicationController
  before_action :authenticate_user!
  before_action :authenticate_admin

  def become
    bypass_sign_in(User.find(params[:id])) # do not update last_sign_in
    redirect_to root_url # or user_root_url
  end

  private

  def authenticate_admin
    head :unauthorized unless current_user.admin?
  end
end
