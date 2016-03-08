require 'test_helper'

class GithubStatusNotificationServiceTest < ActiveSupport::TestCase
  let(:subject) { GithubStatusNotificationService.new(_test_run) }

  describe '#options_for_publish' do
    describe 'when a test run is setting up' do
      let(:_test_run) { FactoryGirl.create(:testributor_run, status: TestStatus::SETUP) }

      it 'creates correct options for the relevant test_run status' do
        # create_status(repo, sha, state, options = {})

        subject.options_for_publish.must_equal(
          { :repo_id => _test_run.project.repository_id,
            :test_run_commit => "123456",
            :status => "pending",
            :extra_github_options => {
              :context=> "testributor.com",
              :target_url=> "http://example.com/projects/#{_test_run.project.id}/test_runs/#{_test_run.id}",
              :description=> "Build is going to be testributed soon."
            }
          })
      end
    end

    describe 'when a test run is queued' do
      let(:_test_run) { FactoryGirl.create(:testributor_run, status: TestStatus::QUEUED) }

      it 'creates correct options for the relevant test_run status' do
        # create_status(repo, sha, state, options = {})

        subject.options_for_publish.must_equal(
          { :repo_id => _test_run.project.repository_id,
            :test_run_commit => "123456",
            :status => "pending",
            :extra_github_options => {
              :context=> "testributor.com",
              :target_url=> "http://example.com/projects/#{_test_run.project.id}/test_runs/#{_test_run.id}",
              :description=> "Build is going to be testributed soon."
            }
          })
      end
    end

    describe 'when a test run is running' do
      let(:_test_run) { FactoryGirl.create(:testributor_run, status: TestStatus::RUNNING) }

      it 'creates correct options for the relevant test_run status' do
        # create_status(repo, sha, state, options = {})

        subject.options_for_publish.must_equal(
          { :repo_id => _test_run.project.repository_id,
            :test_run_commit => "123456",
            :status => "pending",
            :extra_github_options => {
              :context=> "testributor.com",
              :target_url=> "http://example.com/projects/#{_test_run.project.id}/test_runs/#{_test_run.id}",
              :description=>"Build is being testributed."
            }
          })
      end
    end

    describe 'when a test run is passed' do
      let(:_test_run) { FactoryGirl.create(:testributor_run, status: TestStatus::PASSED) }

      it 'creates correct options for the relevant test_run status' do
        # create_status(repo, sha, state, options = {})

        subject.options_for_publish.must_equal(
          { :repo_id => _test_run.project.repository_id,
            :test_run_commit => "123456",
            :status => "success",
            :extra_github_options => {
              :context=> "testributor.com",
              :target_url=> "http://example.com/projects/#{_test_run.project.id}/test_runs/#{_test_run.id}",
              :description=>"All checks have passed!"
            }
          })
      end
    end

    describe 'when a test run has failed' do
      let(:_test_run) { FactoryGirl.create(:testributor_run, status: TestStatus::FAILED) }

      it 'creates correct options for the relevant test_run status' do
        # create_status(repo, sha, state, options = {})

        subject.options_for_publish.must_equal(
          { :repo_id => _test_run.project.repository_id,
            :test_run_commit => "123456",
            :status => "failure",
            :extra_github_options => {
              :context=> "testributor.com",
              :target_url=> "http://example.com/projects/#{_test_run.project.id}/test_runs/#{_test_run.id}",
              :description=>"Some specs are failing."
            }
          })
      end
    end

    describe 'when a test run has errors' do
      let(:_test_run) { FactoryGirl.create(:testributor_run, status: TestStatus::ERROR) }

      it 'creates correct options for the relevant test_run status' do
        # create_status(repo, sha, state, options = {})

        subject.options_for_publish.must_equal(
          { :repo_id => _test_run.project.repository_id,
            :test_run_commit => "123456",
            :status => "error",
            :extra_github_options => {
              :context=> "testributor.com",
              :target_url=> "http://example.com/projects/#{_test_run.project.id}/test_runs/#{_test_run.id}",
              :description=>"There are some errors in your build."
            }
          })
      end
    end

    describe 'when a test run is cancelled' do
      let(:_test_run) { FactoryGirl.create(:testributor_run, status: TestStatus::CANCELLED) }

      it 'creates correct options for the relevant test_run status' do
        # create_status(repo, sha, state, options = {})

        subject.options_for_publish.must_equal(
          { :repo_id => _test_run.project.repository_id,
            :test_run_commit => "123456",
            :status => "error",
            :extra_github_options => {
              :context=> "testributor.com",
              :target_url=> "http://example.com/projects/#{_test_run.project.id}/test_runs/#{_test_run.id}",
              :description=>"Your build has been cancelled."
            }
          })
      end
    end
  end
end
