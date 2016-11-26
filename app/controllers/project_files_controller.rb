class ProjectFilesController < DashboardController
  include Controllers::EnsureProject

  before_action :fetch_project_file, only: [:show, :destroy, :update]
  before_action :authorize_resource!

  def index
    testributor_yml = current_project.
      project_files.find_by_path(ProjectFile::JOBS_YML_PATH)
    redirect_to project_settings_file_path(
      current_project, testributor_yml) and return
  end

  def new
    @project_files = sorted_project_files
    @project_file = ProjectFile.new
    @docs = docs

    render :show
  end

  def create
    file = current_project.project_files.create(file_params)
    if file.persisted?
      flash[:notice] = "#{file.path} created"
    else
      flash[:alert] = file.errors.messages.values.join(', ')
    end

    redirect_back(fallback_location: redirect_back_fallback_path)
  end

  def show
    @project_files = sorted_project_files
    @docs = docs
  end

  def destroy
    file_name = @project_file.path
    if @project_file.destroy
      flash[:notice] = "#{file_name} was deleted"
    else
      flash[:alert] = @project_file.errors.messages.values.join(', ')
    end

    redirect_to project_settings_files_path(current_project)
  end

  def update
    if @project_file.update(file_params)
      flash[:notice] = "#{@project_file.path} updated successfully."
    else
      flash[:alert] = @project_file.errors.messages.values.join(', ')
    end

    redirect_back(fallback_location: redirect_back_fallback_path)
  end

  private

  def fetch_project_file
    @project_file = current_project.project_files.find(params[:id])
  end

  def sorted_project_files
    current_project.project_files.sort_by do |f|
      case f.path
      when ProjectFile::JOBS_YML_PATH
        0
      when ProjectFile::BUILD_COMMANDS_PATH
        1
      else
        2
      end
    end
  end

  def docs
    docs = {}
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML,
      fenced_code_blocks: true, disable_indented_code_blocks: true)

    current_project.technologies.map do |t|
      if t.docker_compose_data["documentation"].present?
        docs[t.public_name] =
          markdown.render(t.docker_compose_data["documentation"])
      end
    end
    if current_project.docker_image.docker_compose_data["documentation"].present?
      docs[current_project.docker_image.public_name] = markdown.render(
        current_project.docker_image.docker_compose_data["documentation"])
    end

    docs
  end

  def file_params
    params.require(:project_file).permit(:path, :contents)
  end

  def authorize_resource!
    action_map = {
      index: :read,
      new: :create,
      create: :create,
      show: :update, # show page is actually a form
      update: :update,
      destroy: :destroy
    }

    authorize!(action_map[action_name.to_sym], @project_file || ProjectFile)
  end
end
