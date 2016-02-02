ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require "minitest/rails"
require "minitest/rails/capybara"
require "minitest/pride"
require 'capybara/poltergeist'
# VCR to playback HTTP responses without making actual connections
require 'vcr'
# Cleanup database between tests (Only for JS tests)
require 'database_cleaner'
require 'sidekiq/testing'

VCR.configure do |c|
  c.cassette_library_dir = 'test/vcr_cassettes'
  c.hook_into :webmock
  c.ignore_localhost = true
  c.allow_http_connections_when_no_cassette = false
end

# Inherits from ActiveSupport::TestCase
class ActionController::TestCase
  include Devise::TestHelpers

  before do
    # Clean everything in "test" redis database before each test
    Katana::Application.redis.flushdb
    # Stub client_id with a random id so that
    # ApplicationHelper#github_oauth_authorize_url won't break
    Octokit.stubs(:client_id).returns("aRandomID")
    @request.env["devise.mapping"] = Devise.mappings[:user]
    ActionMailer::Base.deliveries.clear
  end
end

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #fixtures :all

  ActiveRecord::Migration.check_pending!
  Sidekiq::Testing.inline!

  before do
    yaml = <<-YAML
      each:
        pattern: ".*"
        command: "bin/rake test %{file}"
    YAML
    Octokit::Client.any_instance.stubs(:contents).
      with { |*args| args[1][:path] == ProjectFile::JOBS_YML_PATH }.
      returns(OpenStruct.new(content: Base64.encode64(yaml)))
    tree = OpenStruct.new(
      tree: [OpenStruct.new({path: 'test/models/stub_test_1.rb'}),
             OpenStruct.new({path: 'test_models/stub_test_2.rb'})])
    Octokit::Client.any_instance.stubs(:tree).returns(tree)

    commit_github_response =
      Sawyer::Resource.new(Sawyer::Agent.new('api.example.com'),
        {
          sha: '034df43',
          commit: {
            message: 'Some commit messsage',
            html_url: 'Some url',
            author: {
              name: 'Great Author',
              email: 'great@author.com',
            },
            committer: {
              name: 'Great Committer',
              email: 'great@committer.com',
            }
          },
          author: { login: 'authorlogin' },
          committer: { login: 'committerlogin' }
        }
      )
    TrackedBranch.any_instance.stubs(:sha_history).returns([
      commit_github_response,
      commit_github_response,
      commit_github_response])
  end
end

# Inherits from ActiveSupport::TestCase
class ActionDispatch::IntegrationTest
  include Warden::Test::Helpers
end

class Capybara::Rails::TestCase
  include Warden::Test::Helpers

  Warden.test_mode!
  Capybara.javascript_driver = :poltergeist

  # Transactional fixtures do not work with Selenium tests, because Capybara
  # # uses a separate server thread, which the transactions would be hidden
  # from. We hence use DatabaseCleaner to truncate our test database.
  # @see http://stackoverflow.com/questions/10904996/difference-between-truncation-transaction-and-deletion-database-strategies
  self.use_transactional_fixtures = false

  before do
    Project.any_instance.stubs(:create_webhooks!).returns(1)
    # Stub client_id with a random id so that
    # ApplicationHelper#github_oauth_authorize_url won't break
    Octokit.stubs(:client_id).returns("aRandomID")
    TrackedBranch.any_instance.stubs(:sha_history).returns([
      "31ee93316d0665ab3d9c3fda7986cbf3af550d72",
      "ec21cd4151e5eb92bd56dec6e9fbf72af81f4735",
      "78e21cb09836dbb725487a70ff37da277ee4f785"])
    ActionMailer::Base.deliveries.clear

    # No javascript tests
    if Capybara.current_driver == :rack_test
      DatabaseCleaner.strategy = :transaction
      DatabaseCleaner.start
    else # Javascript tests
      # @see http://stackoverflow.com/questions/10904996/difference-between-truncation-transaction-and-deletion-database-strategies
      DatabaseCleaner.strategy = :deletion
    end
  end

  def teardown
    DatabaseCleaner.clean
    Warden.test_reset!
  end
end
require 'minitest/unit'
require 'mocha/mini_test'

OmniAuth.config.test_mode = true
OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
  :provider => 'github',
  :uid => '123545',
  :info => {
    :email => 'spyros@github.com'
  }
})

if ENV['RUBYMINE']
  require 'minitest/reporters'
  reporters = [Minitest::Reporters::RubyMineReporter.new]
  MiniTest::Reporters.use!(reporters)
end
