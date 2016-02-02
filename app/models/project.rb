class Project < ActiveRecord::Base
  attr_accessor :about_to_be_destroyed

  include Models::RedisLiveUpdates
  # We want this for github_webhook_url
  include Rails.application.routes.url_helpers

  ACTIVE_WORKER_THRESHOLD_SECONDS = 20

  devise :database_authenticatable
  belongs_to :user # this is the owner of the project
  has_many :tracked_branches, dependent: :destroy
  has_many :test_runs, through: :tracked_branches
  has_many :test_jobs, through: :test_runs
  has_one :docker_image_selection
  has_many :project_participations, dependent: :destroy
  has_many :members, through: :project_participations, class_name: "User",
    source: :user
  has_many :user_invitations, dependent: :destroy
  has_many :invited_users, through: :user_invitations, class_name: 'User',
    source: :user
  has_many :project_files, dependent: :destroy
  has_one :oauth_application, class_name: 'Doorkeeper::Application',
    as: :owner, dependent: :destroy
  belongs_to :docker_image # This is the base image
  has_many :technology_selections
  has_many :technologies, through: :technology_selections

  validates :name, :user, presence: true
  validates :name, uniqueness: { scope: :user }
  validate :check_user_limit, if: :user_id_changed?

  before_create :set_secure_random
  # Set this flag to true in order to destroy testributor.yml and
  # build_commands.sh which can't be deleted otherwise.
  # Use prepend: true to guarantee that it is called before childrens'
  # destroy methods.
  before_destroy :set_about_to_be_destroyed, prepend: true
  # TODO: Run cron job to ensure all owners are also participants
  after_create :add_owner_to_participants
  after_create :create_build_commands_file

  attr_accessor :fork

  def to_param
    "#{id}-#{name}"
  end

  def workers_redis_key
    "project_#{id}_workers"
  end

  def test_runs_chunks_redis_key
    "project_#{id}_test_run_chunks"
  end

  # Updates the project's set of workers with only the active
  # and returns the list of active worker uuids
  # Only this method should be called to find the active workers since directly
  # quering for the key in Redis will not clean up the list
  # http://stackoverflow.com/a/8833058
  def update_active_workers
    redis = Katana::Application.redis
    key = workers_redis_key
    active = redis.sort(key, by: 'nosort', get: '*').compact
    redis.multi do
      redis.del(key)
      redis.sadd(key, active) if active.any?
    end

    active
  end
  alias :active_workers :update_active_workers

  def owner_and_name
    "#{repository_owner}/#{repository_name}"
  end

  def create_webhooks!
    begin
      hook = user.github_client.create_hook(repository_id, 'web',
        {
          secret: ENV['GITHUB_WEBHOOK_SECRET'],
          url: webhook_url, content_type: 'json'
        }, events: %w(push delete))
    rescue Octokit::UnprocessableEntity => e
      if e.message =~ /hook already exists/i
        hooks = user.github_client.hooks(repository_id)
        hook = hooks.select do |h|
          h.config.url == webhook_url && h.events == %w(push delete)
        end.first
      else
        raise e
      end
    end
  end

  def create_oauth_application!
    app = Doorkeeper::Application.new(
      name: repository_id,
      redirect_uri: Katana::Application::HEROKU_URL)
    app.owner_id = id
    app.owner_type = 'Project'
    app.save

    app
  end

  def generate_docker_compose_yaml
    return false if docker_image.blank?

    attributes_hash = {}

    # Add linked images
    technologies.each_with_index do |technology, index|
      data = technology.docker_compose_data
      image_attributes = {}
      image_attributes["image"] = technology.hub_image
      if data["environment"].present?
        image_attributes["environment"] = data["environment"]
      end
      attributes_hash[technology.standardized_name] = image_attributes
    end

    # Now add the base image
    base_image_attributes = {}
    base_image_attributes["image"] = docker_image.hub_image
    base_image_attributes["command"] = "/bin/bash -l get_and_run_testributor.sh"
    if technologies.any?
      base_image_attributes["links"] = technologies.map do |tech|
        link = tech.standardized_name
        if tech.docker_compose_data["alias"]
          link += ":#{tech.docker_compose_data["alias"]}"
        end

        link
      end
    end
    base_image_attributes["environment"] = {
      'APP_ID' => oauth_application.uid,
      'APP_SECRET' => oauth_application.secret,
      'API_URL' => "http://www.testributor.com/api/v1/"
    }

    # Merge any additional base image variables
    if docker_image.docker_compose_data["environment"]
      base_image_attributes["environment"].merge!(
        docker_image.docker_compose_data["environment"])
    end
    attributes_hash[docker_image.standardized_name] = base_image_attributes

    attributes_hash.to_yaml
  end

  private

  def set_about_to_be_destroyed
    self.about_to_be_destroyed = true
  end

  # Don't let a project be assigned to a user if projects limit
  # has been reached
  def check_user_limit
    if user && !user.can_create_new_project?
      errors.add(:base, :project_limit_reached)
    end
  end

  def webhook_url
    ENV['GITHUB_WEBHOOK_URL'] ||
      github_webhook_url(host: "www.testributor.com")
  end

  # TODO: Add tests for this
  def add_owner_to_participants
    self.members << self.user
  end

  def create_build_commands_file
    self.project_files.create!(path: ProjectFile::BUILD_COMMANDS_PATH)
  end

  def set_secure_random
    self.secure_random = SecureRandom.hex

    #in case a secure random exists
    while Project.find_by_secure_random(self.secure_random)
      self.secure_random = SecureRandom.hex
    end
  end
end
