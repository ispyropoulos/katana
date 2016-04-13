class ProjectParticipationsController < DashboardController
  include Controllers::EnsureProject

  before_action :set_participation, only: [:update, :destroy]
  before_action :authorize_resource!

  def index
    @participations = current_project.project_participations.includes(:user)
    @invitations = current_project.user_invitations.pending.includes(:user)
  end

  def destroy
    if @participation.destroy
      if @participation.user == current_user
        flash[:notice] =
          "You are no longer a member of #{@participation.project.name} project"
        redirect_to authenticated_root_path
      else
        flash[:notice] = "User is no longer a member of this project"
        redirect_to :back
      end
    else
      flash[:alert] = @participation.errors.full_messages.to_sentence
      redirect_to :back
    end
  end

  def update
    if @participation.update(participation_params)
      flash[:notice] = "Your options were saved"
    else
      flash[:alert] = @participation.errors.full_messages.to_sentence
    end

    redirect_to :back
  end

  private

  def set_participation
    @participation = current_project.project_participations.find(params[:id])
  end

  def participation_params
    params.require(:project_participation).
      permit(:new_branch_notify_on,
             branch_notification_settings_attributes: [:notify_on, :tracked_branch_id, :id])
  end

  def authorize_resource!
    action_map = {
      update: :update,
      destroy: :destroy,
      index: :read
    }

    authorize!(action_map[action_name.to_sym], @participation || ProjectParticipation)
  end
end
