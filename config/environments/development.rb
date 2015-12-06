Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = true

  # http://stackoverflow.com/questions/21605318/how-can-i-serve-requests-concurrently-with-rails-4
  # Read this too: http://tenderlovemaking.com/2012/06/18/removing-config-threadsafe.html
  config.allow_concurrency=true

  # Do not eager load code on boot.
  config.eager_load = true

  #config.preload_frameworks = true
  #config.allow_concurrency = true

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }

  ActionMailer::Base.smtp_settings = {
    address: ENV["MAIL_ADDRESS"] || "in-v3.mailjet.com",
    port: ENV["MAIL_PORT"] || 25,
    user_name: ENV["MAILJET_USERNAME"] || "7963392a7c6c4975905b609d341a5c6e",
    password: ENV["MAILJET_PASSWORD"] || "9cb23e6d75078fce94c9a37c3c788c55",
    authentication: ENV["MAIL_AUTHENTICATION"] || "plain",
    enable_starttls_auto: true
  }
end
