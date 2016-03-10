class ProjectWizard < ActiveRecord::Base

  ORDERED_STEPS = [:choose_provider, :choose_repo, :choose_branches,
                   :configure_testributor, :select_technologies]
  STEP_REQUIREMENTS = {
    choose_provider: "repository_provider",
    choose_repo: "repo_name",
    choose_branches: "branch_names",
    configure_testributor: "testributor_yml",
    select_technologies: "docker_image_id"
  }

  belongs_to :user
  belongs_to :docker_image # This is the base image
  has_many :technology_selections
  has_many :technologies, through: :technology_selections

  validates :user, presence: true
  validates :repository_provider,
    presence: true, on: [:choose_provider, ORDERED_STEPS.last]
  validates :repo_name,
    presence: true, on: [:choose_repo, ORDERED_STEPS.last]
  validates :testributor_yml,
    presence: true, on: [:configure_testributor, ORDERED_STEPS.last]
  validates :branch_names,
    presence: true, on: [:choose_branches, ORDERED_STEPS.last]
  validates :docker_image_id, presence: true, on: :select_technologies
  validate :valid_testributor_yml_contents, on: :configure_testributor

  after_save :reset_fields

  # Which step we need to show to the user according to the missing attributes
  def step_to_show
    ORDERED_STEPS.each do |step|
      requirement = STEP_REQUIREMENTS[step]
      return step if public_send(requirement).blank?
    end

    nil
  end

  def testributor_yml_contents
    File.read(File.join(Rails.root, 'app', 'file_templates', 'testributor.yml'))
  end

  def branch_names=(branch_names)
    if branch_names
      self[:branch_names] = branch_names.select(&:present?)
    else
      self[:branch_names] = nil
    end
    branch_names_will_change!

    branch_names
  end

  def to_project
    # TODO: check the response with a random name
    return false unless (repo = repository_data)

    project = user.projects.find_or_create_by!(name: repo.repository_name) do |_project|
      _project.user = user
      _project.repository_provider = repository_provider
      _project.repository_id = repo.repository_id
      _project.repository_name = repo.repository_name
      # TODO: Add a repository url column and remove repository_owner
      _project.repository_owner = repo.repository_owner
      _project.docker_image = docker_image
      _project.technologies = technologies
    end

    project.project_files.create!(path: "testributor.yml",
                                  contents: testributor_yml)
    project.create_webhooks!
    project.create_oauth_application!

    project
  end

  def create_branches
    project = user.projects.find_by!(
      name: repository_manager.repository_data.repository_name)

    branch_names.each do |branch_name|
      project.tracked_branches.find_or_create_by!(branch_name: branch_name)
    end
  end

  private

  def valid_testributor_yml_contents
    project_file = ProjectFile.new(path: ProjectFile::JOBS_YML_PATH,
                                   contents: testributor_yml)
    project_file.valid?
    copy_errors(project_file.errors)
  end

  def copy_errors(errors)
    errors.to_hash.each do |key, value|
      value.each do |message|
        self.errors.add(key, message)
      end
    end
  end

  def repository_data
    @repository_data ||=
      RepositoryManager.new({ project_wizard: self }).repository_data
  end

  def reset_fields
    if repo_name_changed? && !persisted?
      update_column(:branch_names, [])
    end
  end
end
