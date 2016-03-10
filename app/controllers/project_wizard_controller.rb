class ProjectWizardController < DashboardController
  include Wicked::Wizard
  REDIRECT_MESSAGES = {
    choose_provider: "You need to choose a repository provider first",
    choose_repo: "You need to select a repository first",
    choose_branches: "You need to select a branch first",
    configure_testributor: "You need to configure testributor.yml",
    select_technologies: "You need to select technologies first",
  }
  steps *ProjectWizard::ORDERED_STEPS
  before_action :fetch_project_wizard

  def show
    # Inform user that he has reached project limit
    if !current_user.can_create_new_project?
      flash[:alert] = I18n.t(
        'activerecord.errors.models.'\
        'project.attributes.base.project_limit_reached')

      redirect_to root_path and return
    end

    if (step_to_show = @project_wizard.step_to_show) != step && step_to_show &&
      ProjectWizard::ORDERED_STEPS.index(step_to_show).to_i <
        ProjectWizard::ORDERED_STEPS.index(step).to_i

      flash[:alert] = REDIRECT_MESSAGES[step_to_show]
      redirect_to project_wizard_path(step_to_show) and return
    end

    case step
    when :choose_provider
    when :choose_repo
    when :choose_branches
      # TODO: Make this asynchronous, as in choose_repo
      manager = RepositoryManager.new({ project_wizard: @project_wizard })
      @branches = manager.fetch_branches
    when :configure_testributor
    when :select_technologies
    end

    render_wizard
  end

  def update
    case step
    when :choose_provider
      @project_wizard.assign_attributes({repository_provider: params[:repository_provider]})
    when :choose_repo
      @project_wizard.assign_attributes({repo_name: params[:repo_name]})
    when :choose_branches
      # We use the overriden branch_names= method because postgres
      # array type requires branch_names_will_change! in order to save
      # branch_names to DB
      @project_wizard.branch_names = params[:branch_names]
    when :configure_testributor
      @project_wizard.assign_attributes({
        testributor_yml: params[:testributor_yml]})
    when :select_technologies
      @project_wizard.assign_attributes(selected_technologies_params)
      begin
        @project_wizard.technologies =
          DockerImage.technologies.where(id: params[:technology_ids])
      rescue ActiveRecord::RecordInvalid => invalid
        flash[:alert] = invalid.record.errors.to_a.to_sentence
        render :select_technologies and return
      end
    end

    if @project_wizard.save(context: step)
      if step == ProjectWizard::ORDERED_STEPS.last
        project = @project_wizard.to_project
        @project_wizard.create_branches
        @project_wizard.destroy
        redirect_to instructions_project_path(project) and return
      end

      redirect_to next_wizard_path
    else
      flash[:alert] = @project_wizard.errors.messages.values.join(',')
      redirect_to :back
    end
  end

  def fetch_repos
    redirect_to project_wizard_path(:choose_repo) and return if !request.xhr?

    manager = RepositoryManager.new({ project_wizard: @project_wizard })
    @response_data = manager.fetch_repos(params[:page])

    render "#{@project_wizard.repository_provider}_fetch_repos", layout: false
  end

  private

  def fetch_project_wizard
    @project_wizard =
      ProjectWizard.find_or_create_by(user_id: current_user.id)
  end

  def selected_technologies_params
    params.require(:project_wizard).permit(:docker_image_id)
  end
end
