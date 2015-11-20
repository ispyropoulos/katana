class Project < ActiveRecord::Base
  TESTRIBUTOR_GEM_VERSION = '2.2.0'
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
  has_one :oauth_application, class_name: 'Doorkeeper::Application', as: :owner, dependent: :destroy
  belongs_to :docker_image # This is the base image
  has_many :technology_selections
  has_many :technologies, through: :technology_selections

  validates :name, :user, presence: true
  validates :name, uniqueness: { scope: :user }
  validate :check_user_limit, if: :user_id_changed?

  before_create :set_secure_random
  # TODO: Run cron job to ensure all owners are also participants
  after_create :add_owner_to_participants

  attr_accessor :fork

  def to_param
    "#{id}-#{name}"
  end

  def workers_redis_key
    "project_#{id}_workers"
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
    techs = {}
    technologies.each_with_index do |technology, index|
      techs.merge!({
        technology.standardized_name => { "image" => technology.try(:hub_image) }
      })
    end

    language = { 'base' =>
                 {
                   'image' => docker_image.try(:hub_image),
                   'command' => "/bin/bash -l -c rvm #{TESTRIBUTOR_GEM_VERSION} do testributor",
                   'links' => techs.keys,
                   'environment' => {
                     'APP_ID' => oauth_application.uid,
                     'APP_SECRET' => oauth_application.secret,
                     'APP_URL' => "http://www.testributor.com/api/v1/"
                   }
                 }
               }
    techs.merge(language).to_yaml
  end

  private

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

  def set_secure_random
    self.secure_random = SecureRandom.hex

    #in case a secure random exists
    while Project.find_by_secure_random(self.secure_random)
      self.secure_random = SecureRandom.hex
    end
  end
end
