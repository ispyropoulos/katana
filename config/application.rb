require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Katana
  class Application < Rails::Application

    cattr_accessor :redis

    # we will be using this url for the api in order to avoid buying our
    # own ssl certificate. Also in order to create an OauthApplication the
    # redirect_uri must be https. There is a validation for that.
    HEROKU_URL = 'https://testributor.herokuapp.com'

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.autoload_paths << Rails.root.join('lib')

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    config.active_job.queue_adapter = :sidekiq
    config.exceptions_app = self.routes
    config.react.addons = true

    config.filter_parameters << :private_key

    config.middleware.use Rack::Attack
    ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, req|
      if req.env["rack.attack.match_type"] == :throttle
        Rails.logger.info "Throttled request from #{req.ip}. Data: " +
          req.env['rack.attack.throttle_data'].to_s
      end
    end
  end
end
