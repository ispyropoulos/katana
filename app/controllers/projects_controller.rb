class ProjectsController < DashboardController
  include ApplicationHelper
  include Controllers::EnsureProject

  # skip devise method
  skip_before_action :authenticate_user!, :only => [:show, :status]
  before_action :authorize_resource!

  def show
    redirect_to project_test_runs_path(current_project)
  end

  def update
    notice = nil
    alert = nil

    current_project.assign_attributes(project_params)
    current_project.technologies = DockerImage.technologies.
      where(id: project_params[:technology_ids])

    if current_project.save
      notice = "Project successfully updated"
    else
      alert = current_project.errors.full_messages.join(', ')
    end

    respond_to do |fmt|
      fmt.json do
        if alert
          render json: { notice: notice, alert: alert, docker_compose_yml_contents: '' }
        else
          yml_contents = current_project.generate_docker_compose_yaml(
            current_project.worker_groups.first.try(:oauth_application_id))

          if yml_contents.blank?
            yml_contents = "No worker group found. Please add a worker group first."
          end

          render json: { notice: notice, docker_compose_yml_contents: yml_contents }
        end
      end

      fmt.html do
        flash[:notice] = notice
        flash[:alert] = alert
        redirect_back(fallback_location: redirect_back_fallback_path)
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
      redirect_back(fallback_location: redirect_back_fallback_path)
    end
  end

  def status
    status = nil
    if params[:branch].present?
      branch = current_project.tracked_branches.
        where(branch_name: params[:branch]).first

      if branch
        # NOTE: We only show terminal statuses on badges.
        last_run_with_terminal_status = branch.test_runs.
          terminal_status.order(:created_at).last
        if last_run_with_terminal_status
          status = last_run_with_terminal_status.status.text.downcase
        end
      end
    end

    file = if status
      Rails.root.join('app' , 'assets', 'images', "build-status-#{status}.svg")
    else
      Rails.root.join('app' , 'assets', 'images', 'build-status-unknown.svg')
    end

    # Don't cache the badge
    # https://github.com/github/markup/issues/224
    expires_now
    if stale?(Time.now) # Add a new Etag header on every request (always expired request)
      send_file file, disposition: 'inline', format: :svg
    end
  end

  private

  def current_project
    super(:id)
  end

  def project_params
    params.require(:project).permit(:auto_track_branches, :docker_image_id,
                                    :repository_url, :custom_docker_compose_yml,
                                    technology_ids: [])
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
      status: :read,
      docker_compose: :read_docker_compose,
      toggle_private: :manage # we are being deliberately strict
    }

    authorize!(action_map[action_name.to_sym], current_project)
  end
end
