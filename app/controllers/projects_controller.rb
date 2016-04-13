class ProjectsController < DashboardController
  include ApplicationHelper
  include Controllers::EnsureProject

  # skip devise method
  skip_before_filter :authenticate_user!, :only => [:show]
  before_action :authorize_resource!

  def show
    @branches = current_project.tracked_branches.
      includes(test_runs: :test_jobs)
  end

  def instructions
  end

  def update
    notice = nil
    alert = nil
    begin
      current_project.assign_attributes(project_params)
      current_project.technologies = DockerImage.technologies.
        where(id: project_params[:technology_ids])
      current_project.save
      notice = "Project successfully updated"
    rescue ActiveRecord::RecordInvalid => invalid
      alert = invalid.record.errors.messages.values.join(', ')
    end

    respond_to do |fmt|
      fmt.json do
        yml_contents = current_project.generate_docker_compose_yaml(
          current_project.worker_groups.first.oauth_application_id)

        render json: { notice: notice, alert: alert,
                       docker_compose_yml_contents: yml_contents }
      end

      fmt.html do
        flash[:notice] = notice
        flash[:alert] = alert
        redirect_to :back
      end
    end
  end

  def destroy
    project = current_user.projects.find(params[:id])

    if project.destroy
      manager = RepositoryManager.new(project)
      manager.cleanup_for_removal

      flash[:notice] =
        "Successfully destroyed '#{project.name}' project."
    else
      flash[:alert] =
        "Could not destroy '#{project.name}' project."
    end

    redirect_to root_path
  end

  def docker_compose
    send_data current_project.generate_docker_compose_yaml(params[:client_id]),
      type: 'text/yml; charset=UTF-8;',
      disposition: 'attachment; filename=docker-compose.yml'
  end

  def toggle_private
    current_project.is_private = !current_project.is_private
    if current_project.save
      flash[:notice] = "Your project is now #{ current_project.is_private? ? 'private' : 'public'}."
      redirect_to :back
    end
  end

  private

  def current_project
    super(:id)
  end

  def project_params
    params.require(:project).permit(:docker_image_id, technology_ids: [])
  end

  def api_client_params
    params.require(:api_client).permit(:oauth_application_id, :ssh_key_private,
      :ssh_key_provider_friendly_name)
  end

  def authorize_resource!
    action_map = {
      retry: :update,
      update: :update,
      destroy: :destroy,
      show: :read,
      instructions: :read_instructions,
      docker_compose: :read_docker_compose,
      toggle_private: :manage # we are being deliberately strict
    }

    authorize!(action_map[action_name.to_sym], current_project)
  end
end
