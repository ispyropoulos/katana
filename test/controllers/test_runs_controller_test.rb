#|--------------------------------------------------------------|
#|                     TestRun Access Overview                  |
#|--------------------------------------------------------------|
#| Signed Up | Project Exists | Project Public | Owner | Access |
#|--------------------------------------------------------------|
#|     X     |       Y        |       X        |   X   |    X   |
#|     X     |       Y        |       Y        |   X   |    Y   |
#|     Y     |       Y        |       Y        |   Y   |    Y   |
#|     Y     |       Y        |       X        |   Y   |    Y   |
#|--------------------------------------------------------------|
# X = is the negative, Y is the possitive.
# E.g the 3rd line. When the user is not signed up,
# and the projects exists and it is public and the user
# is not an owner then he has access.

require 'test_helper'

class TestRunsControllerTest < ActionController::TestCase
  let(:project) { FactoryGirl.create(:project) }
  let(:random_user) { FactoryGirl.create(:user) }
  let(:branch) { FactoryGirl.create(:tracked_branch, project: project) }
  let(:_test_run) do
    FactoryGirl.create(:testributor_run, tracked_branch: branch, project: project)
  end
  let(:branch_name) { branch.branch_name }
  let(:commit_sha) { "23423849" }
  let(:branch_github_response) do
    [Sawyer::Resource.new(Sawyer::Agent.new('api.example.com'),
      { sha: commit_sha,
        commit: {
          author: {
            name: "Great Author",
            email: "great@autho.com",
            date: "2016-02-26 14:34:20 UTC"
          },
        committer: {
          name: "Great Commiter",
          email: "great@comitter.com",
          date: "2016-03-07 09:29:00 UTC",
          avatar_url: 'http://avatar.url'
        },
        message: "Some commit message",
        tree: {
          sha: "6dad33ccceed49b4ab376d38565e3c24bf067ae2",
          url: "https://api.github.com/repos/ispyropoulos/katana/git/trees/6dad33ccceed49b4ab376d38565e3c24bf067ae2"
        },
        comment_count: 0
      },
      url: "https://api.github.com/repos/ispyropoulos/katana/commits/322598a3b4d8b946202f5cd685a3c774a43d6778",
      html_url: "Some url",
      author: {
        login: "great_author",
      },
      committer: {
        login: "spyrbri",
        avatar_url: 'http://avatar.url'
      }
    })]
  end

  describe 'When project is private' do
    before do
      _test_run
      contents = {
        each: {
          "command" => 'bin/rake test',
          "pattern" => 'test\/*\/*_test.rb'
        }
      }.to_yaml
      project.project_files.create!(
        path: ProjectFile::JOBS_YML_PATH, contents: contents)
      sign_in project.user, scope: :user
      request.env["HTTP_REFERER"] = "previous_path"
    end

    describe 'When the user is the owner of the project' do
      describe "GET#show" do
        it "returns 200" do
          get :show, params: { project_id: project.id, id: _test_run.id }
          assert_response :ok
        end

        it "returns 404 when requesting a test_run of a different project" do
          different_project_run = FactoryGirl.create(:testributor_run)
          ->{
            get :show, params: { project_id: project.id, 
                                 id: different_project_run.id }
          }.must_raise ActiveRecord::RecordNotFound
        end
      end

      describe "POST#create" do
        it "sets :notice when RepositoryManager#create_test_run! is true" do
          RepositoryManager.any_instance.stubs(:create_test_run!).returns(true)
          post :create, params: { project_id: project.to_param, 
                                  branch_id: branch.id }

          flash[:notice].must_equal "Your build is being setup"
        end

        it "sets :alert when RepositoryManager#create_test_run! is nil" do
          RepositoryManager.any_instance.stubs(:create_test_run!).returns(nil)
          RepositoryManager.any_instance.stubs(:errors).returns(
            ["#{branch.branch_name} doesn't exist anymore on github"])
          post :create, params: { project_id: project.to_param, 
                                  branch_id: branch.id }

          flash[:alert].
            must_equal("#{branch.branch_name} doesn't exist anymore on github")
        end

        it "creates a TestRun with correct attributes" do
          GithubRepositoryManager.any_instance.stubs(:sha_history).
            returns(branch_github_response)
          post :create, params: { project_id: project.to_param, 
                                  branch_id: branch.id }

          TestRun.count.must_equal 2
          _test_run = TestRun.last
          _test_run.tracked_branch_id.must_equal branch.id
          _test_run.status.code.must_equal TestStatus::SETUP
        end
      end

      describe "POST#retry" do
        it "does not allow retying queued runs" do
          job_ids = _test_run.test_jobs.pluck(:id).sort
          _test_run.update_column(:status, TestStatus::QUEUED)
          post :retry, params: { project_id: project.to_param, 
                                 id: _test_run.id }
          flash[:alert].must_equal "Retrying ##{_test_run.id} test run is not allowed at this time"

          _test_run.reload.status.code.must_equal TestStatus::QUEUED
          _test_run.test_jobs.pluck(:id).sort.must_equal job_ids
        end

        # https://trello.com/c/pDr9CgT9/128
        it "does not allow retying cancelled runs" do
          job_ids = _test_run.test_jobs.pluck(:id).sort
          _test_run.update_column(:status, TestStatus::CANCELLED)
          post :retry, params: { project_id: project.to_param, 
                                 id: _test_run.id }
          flash[:alert].must_equal "Retrying ##{_test_run.id} test run is not allowed at this time"

          _test_run.reload.status.code.must_equal TestStatus::CANCELLED
          _test_run.test_jobs.pluck(:id).sort.must_equal job_ids
        end

        # https://trello.com/c/ITi9lURr/127
        it "does not allow retying running runs" do
          job_ids = _test_run.test_jobs.pluck(:id).sort
          _test_run.update_column(:status, TestStatus::RUNNING)
          post :retry, params: { project_id: project.to_param, 
                                 id: _test_run.id }
          flash[:alert].must_equal "Retrying ##{_test_run.id} test run is not allowed at this time"

          _test_run.reload.status.code.must_equal TestStatus::RUNNING
          _test_run.test_jobs.pluck(:id).sort.must_equal job_ids
        end

        it "resets the worker_uuid column to let the setup happen again" do
          job_ids = _test_run.test_jobs.pluck(:id).sort
          _test_run.update_columns(status: TestStatus::PASSED,
                                   setup_worker_uuid: "some uuid")
          post :retry, params: { project_id: project.to_param, 
                                 id: _test_run.id }
          flash[:notice].must_equal "The Build will soon be retried"

          _test_run.reload.setup_worker_uuid.must_equal nil
        end

        it "returns 404 when retrying a test_run of a different project" do
          different_project_run = FactoryGirl.create(:testributor_run)
          ->{
            post :retry, params: { project_id: project.id, 
                                   id: different_project_run.id }
          }.must_raise ActiveRecord::RecordNotFound
        end
      end

      describe "PUT#update" do
        it "returns 404 when updating a test_run of a different project" do
          different_project_run = FactoryGirl.create(:testributor_run)
          ->{
            put :update, params: { project_id: project.id, 
                                   id: different_project_run.id }
          }.must_raise ActiveRecord::RecordNotFound
        end
      end
    end

    describe 'When user is a random registered user' do
      before { sign_in random_user, scope: :user }

      describe "GET#show" do
        it "returns 302" do
          -> { 
            get :show, params: { project_id: project.id, 
                                 id: _test_run.id } 
          }.must_raise ActiveRecord::RecordNotFound
        end
      end

      describe "GET#index" do
        it "returns 302" do
          -> { 
            get :index, params: { project_id: project.id, 
                                  branch_id: branch.id } 
          }.must_raise ActiveRecord::RecordNotFound
        end
      end

      describe "POST#create" do
        it "sets :notice when RepositoryManager#create_test_run! is true" do
          -> { 
            post :create, params: { project_id: project.id, 
                                    branch_id: branch.id } 
          }.must_raise ActiveRecord::RecordNotFound
        end
      end

      describe "POST#retry" do
        it 'does not allow the user to retry the test run' do
          -> { 
            post :retry, params: { project_id: project.id, 
                                   id: _test_run.id } 
          }.must_raise ActiveRecord::RecordNotFound
        end
      end

      describe "POST#destroy" do
        it 'does not allow the user to retry the test run' do
          -> { post :destroy, params: { project_id: project.id, 
                                        id: _test_run.id } 
          }.must_raise ActiveRecord::RecordNotFound
        end
      end
    end

    it "creates a TestRun with correct attributes when repo provider is bare_repo and branch is missing" do
      project.update_column(:repository_provider, "bare_repo")
      post :create, params: { project_id: project.to_param, 
                              test_run: { commit_sha: '1234' } }

      TestRun.count.must_equal 2
      _test_run = TestRun.last
      _test_run.commit_sha.must_equal '1234'
      _test_run.status.code.must_equal TestStatus::SETUP
      _test_run.initiator.must_equal project.user
    end
  end

  describe 'when the project is public' do
    let(:public_project) do
      project.update_column(:is_private, false)
      project
    end

    before do
      _test_run
      contents = {
        each: {
          "command" => 'bin/rake test',
          "pattern" => 'test\/*\/*_test.rb'
        }
      }.to_yaml
      project.project_files.create!(
        path: ProjectFile::JOBS_YML_PATH, contents: contents)
    end

    describe 'when the user is registered' do
      before { sign_in random_user, scope: :user }

      describe "GET#show" do
        it "returns 200" do
          get :show, params: { project_id: public_project.id, 
                               id: _test_run.id }
          assert_response :ok
        end
      end

      describe "GET#index" do
        it "returns 200" do
          get :index, params: { project_id: public_project.id, 
                                branch_id: branch.id }
          assert_response :ok
        end
      end

      describe "POST#create" do
        it "sets :notice when RepositoryManager#create_test_run! is true" do
          post :create, params: { project_id: public_project.to_param, 
                                  branch_id: branch.id }
          assert_response 403
        end
      end

      describe "POST#retry" do
        it 'does not allow the user to retry the test run' do
          post :retry, params: { project_id: public_project.to_param, 
                                 id: _test_run.id }
          assert_response 403
        end
      end

      describe "POST#destroy" do
        it 'does not allow the user to retry the test run' do
          post :destroy, params: { project_id: public_project.to_param, 
                                   id: _test_run.id }
          assert_response 403
        end
      end
    end

    describe 'when the user is not registered' do
      describe "GET#show" do
        it "returns 200" do
          get 'show', params: { project_id: public_project.id, 
                                id: _test_run.id }
          assert_response :ok
        end
      end

      describe "GET#index" do
        it "returns 200" do
          get 'index', params: { project_id: public_project.id, 
                                 branch_id: branch.id }
          assert_response :ok
        end
      end

      describe "POST#create" do
        it "sets an alert and redirects to sign in page" do
          post :create, params: { project_id: public_project.to_param, 
                                  branch_id: branch.id }
          flash[:alert].must_equal 'You need to sign in or sign up before continuing.'
          assert_response 302
        end
      end

      describe "POST#retry" do
        it 'does not allow the user to retry the test run' do
          post :retry, params: { project_id: public_project.to_param, 
                                 id: _test_run.id }
          flash[:alert].must_equal 'You need to sign in or sign up before continuing.'
          assert_response 302
        end
      end

      describe "POST#destroy" do
        it 'does not allow the user to retry the test run' do
          post :destroy, params: { project_id: public_project.to_param, 
                                   id: _test_run.id }
          flash[:alert].must_equal 'You need to sign in or sign up before continuing.'
          assert_response 302
        end
      end
    end
  end
end
