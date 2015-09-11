class Users::InvitationsController < Devise::InvitationsController
  before_action :authenticate_user!

  private

  # this is called when accepting invitation
  # should return an instance of resource class
  def accept_resource
    user = resource_class.accept_invitation!(update_resource_params)
    user.participating_organizations << user.invited_by

    user
  end

  def after_invite_path_for(resource_name)
    root_path
  end
end
