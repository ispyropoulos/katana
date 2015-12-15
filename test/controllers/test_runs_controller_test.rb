require 'test_helper'

class TestRunsControllerTest < ActionController::TestCase
  let(:_test_run) { FactoryGirl.create(:testributor_run) }
  let(:branch) { _test_run.tracked_branch }
  let(:branch_name) { branch.branch_name }
  let(:commit_sha) { "23423849" }
  let(:project) { branch.project }
  let(:branch_github_response) do
    Sawyer::Resource.new(Sawyer::Agent.new('api.example.com'),
      {
        name: branch_name,
        commit: {
          sha: commit_sha,
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
      }
    )
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
    it "sets :notice when TrackedBranch#build_test_run_and_jobs is true" do
      TrackedBranch.any_instance.stubs(:build_test_run_and_jobs).returns(true)
      post :create, { project_id: project.to_param, branch_id: branch.id }

      flash[:notice].must_equal "Your build was added to queue"
    end

    it "sets :alert when TrackedBranch#build_test_run_and_jobs is nil" do
      TrackedBranch.any_instance.stubs(:build_test_run_and_jobs).returns(nil)
      post :create, { project_id: project.to_param, branch_id: branch.id }

      flash[:alert].must_equal "#{branch.branch_name} doesn't exist anymore" +
        " on github"
    end

    it "creates a TestRun with correct attributes" do
      TrackedBranch.any_instance.stubs(:from_github).
        returns(branch_github_response)
      post :create, { project_id: project.to_param, branch_id: branch.id }

      TestRun.count.must_equal 2
      _test_run = TestRun.last
      _test_run.tracked_branch_id.must_equal branch.id
      _test_run.status.code.must_equal TestStatus::QUEUED
    end
  end

  describe "POST#retry" do
    it "does not allow retying queued runs" do
      job_ids = _test_run.test_jobs.pluck(:id).sort
      _test_run.update_column(:status, TestStatus::QUEUED)
      post :retry, { project_id: project.to_param, id: _test_run.id }
      flash[:alert].must_equal 'You cannot retry cancelled test runs'

      _test_run.reload.status.code.must_equal TestStatus::QUEUED
      _test_run.test_jobs.pluck(:id).sort.must_equal job_ids
    end

    # https://trello.com/c/pDr9CgT9/128
    it "does not allow retying cancelled runs" do
      job_ids = _test_run.test_jobs.pluck(:id).sort
      _test_run.update_column(:status, TestStatus::CANCELLED)
      post :retry, { project_id: project.to_param, id: _test_run.id }
      flash[:alert].must_equal 'You cannot retry cancelled test runs'

      _test_run.reload.status.code.must_equal TestStatus::CANCELLED
      _test_run.test_jobs.pluck(:id).sort.must_equal job_ids
    end

    # https://trello.com/c/ITi9lURr/127
    it "does not allow retying running runs" do
      job_ids = _test_run.test_jobs.pluck(:id).sort
      _test_run.update_column(:status, TestStatus::RUNNING)
      post :retry, { project_id: project.to_param, id: _test_run.id }
      flash[:alert].must_equal 'You cannot retry cancelled test runs'

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
