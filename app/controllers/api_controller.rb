class ApiController < ActionController::Base
  before_action :doorkeeper_authorize!
  before_action :update_token_last_used_at

  private

  def update_token_last_used_at
    doorkeeper_token.update_column(:last_used_at, Time.current)
  end

  def current_project
    @current_project ||= doorkeeper_token.application.owner
  end
end
