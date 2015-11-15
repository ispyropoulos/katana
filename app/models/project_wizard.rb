class ProjectWizard < ActiveRecord::Base

  ORDERED_STEPS = [:add_project, :add_branches, :configure_testributor,
    :select_technologies]
  STEP_REQUIREMENTS = {
    add_project: "repo_name",
    add_branches: "branch_names",
    configure_testributor: "testributor_yml",
    select_technologies: "selected_technologies"
  }
  AVAILABLE_TECHNOLOGIES = %w(
    postgres9.4 postgres9.3 postgres9.2 rails4.1 redis mongo postgis)

  belongs_to :user

  validates :user, presence: true
  validates :testributor_yml,
    presence: true, on: [:configure_testributor, ORDERED_STEPS.last]
  validates :repo_name,
    presence: true, on: [:add_project, ORDERED_STEPS.last]
  validates :testributor_yml,
    presence: true, on: [:configure_testributor, ORDERED_STEPS.last]
  validates :branch_names,
    presence: true, on: [:add_branches, ORDERED_STEPS.last]
  validates :selected_technologies, presence: true, on: :select_technologies

  after_save :reset_fields

  # When github client is not set, this method returns false.
  # We should prompt the user to connect to github.
  def fetch_repos
    client = user.github_client
    return false unless client.present?

    existing_repo_names = user.projects.pluck(:repository_id)
    client.repos.reject do |repo|
      repo.owner.login != client.user.login || repo.id.in?(existing_repo_names)
    end.map do |repo|
      { id: repo.id, fork: repo.fork?, name: repo.full_name }
    end
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
      _project.repository_provider = 'github'
      _project.repository_id = repo.id
      _project.repository_name = repo.name
      _project.repository_owner = repo.owner.login
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

  def repo
    @repo ||= user.github_client.repo(repo_name)
  end

  def reset_fields
    if repo_name_changed? && !persisted?
      update_column(:branch_names, [])
    end
  end
end