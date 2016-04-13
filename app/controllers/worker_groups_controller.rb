class WorkerGroupsController < DashboardController
  include Controllers::EnsureProject

  before_action :fetch_worker_group, only: [:update, :destroy, :reset_ssh_key]
  before_action :authorize_resource!

  def create
    current_project.create_oauth_application!
    flash[:notice] = "A Worker Group has been created."

    redirect_to :back
  end

  def update
    unless request.xhr?
      head :bad_request and return
    end

    @worker_group.update!(worker_group_params)

    render @worker_group
  end

  def destroy
    current_project.destroy_oauth_application!(@worker_group.oauth_application_id)
    flash[:notice] = "The Worker Group was deleted."

    redirect_to :back
  end

  def reset_ssh_key
    @worker_group.reset_ssh_key!

    flash[:notice] =
      "The SSH key for the \"#{@worker_group.friendly_name}\" "\
        "Worker Group is now reset."

    redirect_to :back
  end

  private

  def fetch_worker_group
    @worker_group = current_project.worker_groups.find(params[:id])
  end

  def worker_group_params
    params.require(:worker_group).permit(:friendly_name)
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
