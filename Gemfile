source 'https://rubygems.org'

ruby '2.2.0'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.2.3'
gem 'pg'
gem 'redis'

gem 'wicked'
gem 'sidekiq'
gem 'select2-rails'
gem 'draper'
gem 'haml-rails'
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '>= 1.3.0'
gem 'coffee-rails', '~> 4.1.0'
gem 'bootstrap-sass'
gem 'bootstrap-social-rails'
gem 'font-awesome-rails'
gem 'exception_notification'
gem 'gretel'

# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

gem 'jquery-rails'
gem 'jbuilder', '~> 2.0'
gem 'sdoc', '~> 0.4.0', group: :doc

gem 'devise'
gem 'cancancan', '~> 1.10'
gem 'underscore-rails'
gem 'octokit', '~> 4.0'
gem 'attr_encrypted'
# commit that fixes the creation of tokens in client_credentials flow
gem 'doorkeeper', github: 'doorkeeper-gem/doorkeeper', ref: ' f9d5e3d'
gem 'oauth2'
gem 'omniauth-github'
gem 'active_model_serializers', :github => 'rails-api/active_model_serializers', :ref => '1f0886' # 0.10 rc version
gem 'simple_form'

group :production do
  gem 'rails_12factor'
  gem 'puma'
end

group :test do
  gem "factory_girl_rails"
  gem "capybara"
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

group :development, :test do
  gem 'byebug'
  # Call 'binding.pry' anywhere in the code to stop execution and get a debugger console
  gem 'pry-rails'
  gem 'pry-nav'
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2.0'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
end
