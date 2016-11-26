source 'https://rubygems.org'

ruby '2.3.0'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.0'
gem 'haml-rails'
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '>= 1.3.0'
gem 'coffee-rails', '~> 4.1.0'

# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'jbuilder', '~> 2.0'
gem 'sdoc', '~> 0.4.0', group: :doc

# Use SafeYAML for user defined yml parsing
gem "safe_yaml", require: false

gem 'pg'
gem 'redis'
gem 'connection_pool'
gem 'react-rails', '~> 1.6.0'
gem 'react-bootstrap-rails'
gem 'wicked'
gem 'sidekiq'
gem 'sinatra', require: false
gem 'select2-rails'
gem 'draper', github: 'drapergem/draper', ref: '957507f'
gem 'bootstrap-sass'
gem 'bootstrap-social-rails'
gem 'font-awesome-rails'
gem 'exception_notification', '~> 4.2.1'
gem 'slack-notifier'
gem 'gretel'
gem 'rack-timeout'
gem 'redcarpet'
gem 'rack-attack'
gem 'awesome_print'
gem 'sshkey'
gem 'devise'
gem 'cancancan', '~> 1.10'
gem 'underscore-rails'
gem 'octokit', '~> 4.0'
gem 'attr_encrypted'
# commit that fixes the creation of tokens in client_credentials flow
gem 'doorkeeper', '~>3.1.0'
gem 'oauth2'
gem 'omniauth-github'
gem 'active_model_serializers', github: 'rails-api/active_model_serializers', ref: 'b41df13' # 0.10.2 version
gem 'simple_form'
gem 'actionview-encoded_mail_to'
gem 'fog-aws'
# TODO Switch to the official gem as soon as this branch is merged.
# We implemented some missing BitBucket API support ourselves and fixed a few problems.
gem 'bitbucket_rest_api', github: 'ispyropoulos/bitbucket', branch: 'testributor-extra'
gem 'oauth'
gem 'puma'
gem 'puma-heroku'

group :production do
  gem 'rails_12factor'
  gem 'newrelic_rpm'
  gem 'scout_apm'
end

group :test do
  # As of rails 5 the `assigns` method of ActionController::TestCase is 
  # deprecated. To continue using it, we us the rails-controller-testing gem
  gem 'rails-controller-testing'
  gem 'factory_girl_rails'
  gem 'capybara'
  gem 'poltergeist'
  gem 'minitest-reporters'
  gem 'minitest-rails'
  gem 'minitest-rails-capybara'
  gem 'minitest-spec-rails'
  gem 'mocha'
  gem 'vcr'
  gem 'webmock'
  gem 'database_cleaner'
  gem 'timecop'
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 3.0'
end

group :development, :test do
  gem 'byebug'
  # Call 'binding.pry' anywhere in the code to stop execution and get a debugger console
  gem 'pry-rails'
  gem 'pry-nav'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
end
