class ProjectsController < DashboardController
  include ApplicationHelper
  include Controllers::EnsureProject

  skip_before_action :ensure_project_exists!, only: [:destroy]

  def show
    @branches = current_project.tracked_branches.
      includes(test_runs: :test_jobs)
  end

  def instructions
  end

  def update
    begin
      current_project.assign_attributes(project_params)
      current_project.technologies = DockerImage.technologies.
        where(id: project_params[:technology_ids])
      current_project.save
      flash[:notice] = "Project successfully updated"
      redirect_to :back
    rescue ActiveRecord::RecordInvalid => invalid
      flash[:alert] = invalid.record.errors.messages.values.join(', ')
      redirect_to :back
    end
  end

  def destroy
    project = current_user.projects.find(params[:id])

    if project.destroy
      manager = RepositoryManager.new({ project: project })
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
end
