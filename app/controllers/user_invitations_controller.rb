class UserInvitationsController < DashboardController
  include Controllers::EnsureProject

  # User is not a participant so skip the filter or it will raise 404
  skip_before_action :ensure_project_exists!, only: [:accept]

  def new
    authorize! :manage, current_project

    @invitation = current_project.user_invitations.new
  end

  def create
    authorize! :manage, current_project

    @invitation = current_project.user_invitations.create(invitation_params)

    if @invitation.persisted?
      flash[:notice] = "Invitation will be sent shortly"
    else
      flash[:alert] = @invitation.errors.full_messages.to_sentence
    end

    redirect_back(fallback_location: redirect_back_fallback_path)
  end

  def destroy
    authorize! :manage, current_project

    if invitation.destroy
      flash[:notice] = "Invitation was cancelled"
    else
      flash[:alert] = invitation.errors.full_messages.to_sentence
    end

    redirect_back(fallback_location: redirect_back_fallback_path)
  end

  # GET invitations/accept?token=12312312
  def accept
    invitation =
      UserInvitation.where(accepted_at: nil, token: params[:token]).first!

    if current_user.nil?
      # Store path and prompt user to signup
      store_location_for(:user, accept_user_invitation_path(token: params[:token]))
      authenticate_user!
    else
      # If a member of the project uses the invitation link, show a flash message
      # and don't "use" the invitation.
      if invitation.project.members.include?(current_user)
        flash[:alert] = "You are already a member of this project!"
      else
        invitation.accept!(current_user)
        flash[:notice] = "Welcome to #{invitation.project.name}"
      end
      redirect_to project_path(invitation.project)
    end
  end

  def resend
    authorize! :manage, current_project

    invitation.queue_email
    flash[:notice] = "Invitation will be sent shortly"

    redirect_back(fallback_location: redirect_back_fallback_path)
  end

  private

  def invitation
    @invitation ||= current_project.user_invitations.pending.find(params[:id])
  end

  def invitation_params
    params.require(:user_invitation).permit(:email)
  end
end
