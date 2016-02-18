class AddEnableDesktopNotificationsToProjectsUsers < ActiveRecord::Migration
  def change
    add_column :projects_users, :enable_desktop_notifications,
      :boolean, default: false
  end
end
