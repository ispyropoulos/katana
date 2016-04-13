class SettingsController < DashboardController
  include Controllers::EnsureProject
  before_action :authorize_resource!

  def show
  end

  def worker_setup
  end

  def notifications
  end

  private

  def authorize_resource!
    action_map = {
      notification: :update_own_notification_settings,
      show: :read_general_settings,
      worker_setup: :update_worker_setup
    }

    authorize!(action_map[action_name.to_sym], current_project)
  end
end
