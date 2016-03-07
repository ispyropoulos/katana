class ProjectWizard < ActiveRecord::Base

  ORDERED_STEPS = [:choose_provider, :choose_repo, :choose_branches,
                   :configure_testributor, :select_technologies]
  PROJECTS_PER_PAGE = 20
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

  # When github client is not set, this method returns false.
  # We should prompt the user to connect to github.
  def fetch_repos(page=0)
    client = user.github_client
    page = page.to_i
    return false unless client.present?

    #https://developer.github.com/v3/repos/#list-user-repositories
    repos = client.repos(nil,
      { type: "owner", per_page: PROJECTS_PER_PAGE }.merge(page > 0 ? { page: page } : {})
    ).map { |repo| { id: repo.id, fork: repo.fork?, name: repo.full_name } }

    { repos: repos, last_response: client.last_response }
  end

  # When repo_name is blank or client is blank, this method returns false.
  def fetch_branches
    client = user.github_client
    return false if repo_name.blank? || client.blank?

    client.branches(repo_name).
      map { |b| TrackedBranch.new(branch_name: b.name) }
  end

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
    return false unless repo

    project = user.projects.find_or_create_by!(name: repo.name) do |_project|
      _project.user = user
      _project.repository_provider = repository_provider
      _project.repository_id = repo.id
      _project.repository_name = repo.name
      # TODO: Add a repository url column and remove repository_owner
      _project.repository_owner = repo.owner.login
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
    project = user.projects.find_by!(name: repo.name)
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

  def repo
    @repo ||= user.github_client.repo(repo_name)
  end

  def reset_fields
    if repo_name_changed? && !persisted?
      update_column(:branch_names, [])
    end
  end
end
