ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require "minitest/rails"
require "minitest/rails/capybara"
require "minitest/pride"

class ActionController::TestCase
  include Devise::TestHelpers

  def setup
    @request.env["devise.mapping"] = Devise.mappings[:user]
    ActionMailer::Base.deliveries.clear
  end
end

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #fixtures :all

  ActiveRecord::Migration.check_pending!
end

class ActionDispatch::IntegrationTest
  include Warden::Test::Helpers
end

class Capybara::Rails::TestCase
  include Warden::Test::Helpers
  Warden.test_mode!

  def teardown
    Warden.test_reset!
  end
end
