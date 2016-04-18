class ProjectWizardController < DashboardController
  include Wicked::Wizard
  steps :select_repository, :configure, :add_worker
  before_action :fetch_project

  def show
    # Inform user that he has reached project limit
    if step == steps.first && !current_user.can_create_new_project?
      flash[:alert] =
        I18n.t('activerecord.errors.models.project.attributes.base.project_limit_reached')

      redirect_to root_path and return
    end

    # All steps but the first need @project to exist
    if step != steps.first && @project.blank?
      flash[:alert] = "You need to select a repository first"
      redirect_to project_wizard_path(steps.first)
      return
    end

    render_wizard
  end

  def update
    case step
    when :select_repository
      project = current_user.projects.new(
        project_params.merge(docker_image: DockerImage.first,
                             name: project_params[:repository_name]))

      if project.save
        repository_manager = RepositoryManager.new(project)
        project.webhook_id = repository_manager.post_add_repository_setup.try(:id)
        project.save!

        project.create_testributor_yml_file!
        project.create_oauth_application!

        cookies[:wizard_project_id] = project.id
        flash[:notice] = "Project was created!"
        redirect_to next_wizard_path
      else
        flash[:alert] = project.errors.full_messages.to_sentence
        redirect_to :back
      end
    when :configure
      unless @project.present?
        redirect_to project_wizard_path(steps.first) && return
      end

      testributor_yml =
        @project.project_files.find_or_initialize_by(path: ProjectFile::JOBS_YML_PATH)
      testributor_yml.contents = params[:testributor_yml]
      if testributor_yml.save
        redirect_to next_wizard_path
      else
        flash[:alert] = testributor_yml.errors.full_messages.to_sentence
        redirect_to :back
      end
    when :add_worker
      unless @project.present?
        redirect_to project_wizard_path(steps.first) && return
      end

      cookies.delete(:wizard_project_id)
      redirect_to project_path(@project)
    end
  end

  def fetch_repos
    if !request.xhr? || params[:repository_provider].empty?
      redirect_to project_wizard_path(steps.first) and return
    end

    project = current_user.projects.new(
      repository_provider: params[:repository_provider])

    manager = RepositoryManager.new(project)
    @response_data = manager.fetch_repos(params[:page])

    render "#{project.repository_provider}_fetch_repos", layout: false
  end

  private

  def fetch_project
    @project ||=
      current_user.projects.where(id: cookies[:wizard_project_id]).first
  end

  def project_params
    params.permit(:repository_provider, :repository_owner, :repository_name,
      :repository_id, :repository_slug)
  end
end
