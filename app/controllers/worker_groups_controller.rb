class WorkerGroupsController < DashboardController
  include Controllers::EnsureProject

  before_action :fetch_worker_group, only: [:update, :destroy, :reset_ssh_key]
  before_action :authorize_resource!

  def create
    errors =
      if params[:worker_group].present?
        current_project.create_oauth_application!(
          worker_group_params[:ssh_key_private],
          worker_group_params[:friendly_name])
      else
        current_project.create_oauth_application!
      end

    if errors.present?
      flash[:alert] = errors
    else
      flash[:notice] = "A Worker Group has been created."
    end

    redirect_back(fallback_location: redirect_back_fallback_path)
  end

  def update
    @worker_group.update(worker_group_params)

    if @worker_group.errors.any?
      flash[:alert] = @worker_group.errors.full_messages.to_sentence
    else
      flash[:notice] = "Successfully updated worker group"
    end

    redirect_back(fallback_location: redirect_back_fallback_path)
  end

  def destroy
    current_project.destroy_oauth_application!(@worker_group.oauth_application_id)
    flash[:notice] = "The Worker Group was deleted."

    redirect_back(fallback_location: redirect_back_fallback_path)
  end

  def reset_ssh_key
    @worker_group.reset_ssh_key!

    flash[:notice] =
      "The SSH key for the \"#{@worker_group.friendly_name}\" "\
        "Worker Group is now reset."

    redirect_back(fallback_location: redirect_back_fallback_path)
  end

  private

  def fetch_worker_group
    @worker_group = current_project.worker_groups.find(params[:id])
  end

  def worker_group_params
    result = params.require(:worker_group).permit(:friendly_name, :ssh_key_private)

    if current_project.repository_provider != "bare_repo" || result[:ssh_key_private].blank?
      result.delete(:ssh_key_private)
    end

    result
  end

  def authorize_resource!
    action_map = {
      update: :update,
      reset_ssh_key: :create,
      destroy: :destroy,
      create: :create}

    authorize!(action_map[action_name.to_sym], @worker_group || WorkerGroup)
  end
end
