require 'test_helper'

class TestRunsControllerTest < ActionController::TestCase
  let(:project) { FactoryGirl.create(:project) }
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
          date: "2016-03-07 09:29:00 UTC"
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
      }
    })]
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
    sign_in :user, project.user
    request.env["HTTP_REFERER"] = "previous_path"
  end

  describe "GET#index" do
    it "doesn't allow more than OLD_RUNS_LIMIT TestRuns to be displayed" do
      old_runs_count = TrackedBranch::OLD_RUNS_LIMIT
      FactoryGirl.create_list(:testributor_run,
                              old_runs_count,
                              tracked_branch: branch)
      oldest_run = FactoryGirl.create(:testributor_run,
                                      tracked_branch: branch,
                                      created_at: 20.days.ago)
      get :index, { project_id: project.id, branch_id: branch.id }

      assigns[:test_runs].map(&:id).wont_include oldest_run.id
      assert_select "tbody tr", old_runs_count
    end
  end

  describe "GET#show" do
    it "returns 200" do
      get :show, { project_id: project.id, id: _test_run.id}
      assert_response :ok
    end

    it "returns 404 when requesting a test_run of a different project" do
      different_project_run = FactoryGirl.create(:testributor_run)
      ->{
        get :show, { project_id: project.id, id: different_project_run.id }
      }.must_raise ActiveRecord::RecordNotFound
    end
  end

  describe "POST#create" do
    it "sets :notice when RepositoryManager#create_test_run! is true" do
      RepositoryManager.any_instance.stubs(:create_test_run!).returns(true)
      post :create, { project_id: project.to_param, branch_id: branch.id }

      flash[:notice].must_equal "Your build is being setup"
    end

    it "sets :alert when RepositoryManager#create_test_run! is nil" do
      RepositoryManager.any_instance.stubs(:create_test_run!).returns(nil)
      RepositoryManager.any_instance.stubs(:errors).returns(
        ["#{branch.branch_name} doesn't exist anymore on github"])
      post :create, { project_id: project.to_param, branch_id: branch.id }

      flash[:alert].
        must_equal("#{branch.branch_name} doesn't exist anymore on github")
    end

    it "creates a TestRun with correct attributes" do
      GithubRepositoryManager.any_instance.stubs(:sha_history).
        returns(branch_github_response)
      post :create, { project_id: project.to_param, branch_id: branch.id }

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
      post :retry, { project_id: project.to_param, id: _test_run.id }
      flash[:alert].must_equal "Retrying ##{_test_run.id} test run is not allowed at this time"

      _test_run.reload.status.code.must_equal TestStatus::QUEUED
      _test_run.test_jobs.pluck(:id).sort.must_equal job_ids
    end

    # https://trello.com/c/pDr9CgT9/128
    it "does not allow retying cancelled runs" do
      job_ids = _test_run.test_jobs.pluck(:id).sort
      _test_run.update_column(:status, TestStatus::CANCELLED)
      post :retry, { project_id: project.to_param, id: _test_run.id }
      flash[:alert].must_equal "Retrying ##{_test_run.id} test run is not allowed at this time"

      _test_run.reload.status.code.must_equal TestStatus::CANCELLED
      _test_run.test_jobs.pluck(:id).sort.must_equal job_ids
    end

    # https://trello.com/c/ITi9lURr/127
    it "does not allow retying running runs" do
      job_ids = _test_run.test_jobs.pluck(:id).sort
      _test_run.update_column(:status, TestStatus::RUNNING)
      post :retry, { project_id: project.to_param, id: _test_run.id }
      flash[:alert].must_equal "Retrying ##{_test_run.id} test run is not allowed at this time"

      _test_run.reload.status.code.must_equal TestStatus::RUNNING
      _test_run.test_jobs.pluck(:id).sort.must_equal job_ids
    end

    it "returns 404 when retrying a test_run of a different project" do
      different_project_run = FactoryGirl.create(:testributor_run)
      ->{
        post :retry, { project_id: project.id, id: different_project_run.id }
      }.must_raise ActiveRecord::RecordNotFound
    end
  end

  describe "PUT#update" do
    it "returns 404 when updating a test_run of a different project" do
      different_project_run = FactoryGirl.create(:testributor_run)
      ->{
        put :update, { project_id: project.id, id: different_project_run.id }
      }.must_raise ActiveRecord::RecordNotFound
    end
  end
end
