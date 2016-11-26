require 'test_helper'

class TrackedBranchesControllerTest < ActionController::TestCase
  let(:branch_name) { "master" }
  let(:project)  { FactoryGirl.create(:project) }
  let(:owner) { project.user }
  let(:branch_params) do
    { branch_name: branch_name }.merge(project_id: project.id)
  end
  let(:filename_1) { "test/models/user_test.rb" }
  let(:filename_2) { "test/models/hello_test.rb" }
  let(:commit_sha) { "034df43" }
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
          avatar_url: "http://dummy.url"
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
        login: "authorlogin",
      },
      committer: {
        login: "committerlogin",
        avatar_url: "http://dummy.url"
      }
    })]
  end

  describe "POST#create" do
    before do
      project
      GithubRepositoryManager.any_instance.stubs(:sha_history).
        returns(branch_github_response)
      sign_in owner, scope: :user
    end

    it "adds errors to flash when tracked_branch.invalid?" do
      # Create a branch with same branch_name so that uniqueness validation
      # is triggered
      project.tracked_branches.create(branch_name: branch_name)
      post :create, params: branch_params
      flash[:alert].wont_be :empty?
    end

    it "doesn't call build_test_run_and_jobs when tracked_branch.invalid?" do
      TrackedBranch.any_instance.stubs(:invalid?).returns(true)
      TrackedBranch.any_instance.expects(:build_test_run_and_jobs).never
      post :create, params: branch_params
    end

    it "adds errors to flash when build_test_run_and_jobs returns nil" do
      GithubRepositoryManager.any_instance.stubs(:create_test_run!).returns(nil)
      RepositoryManager.any_instance.stubs(:errors).returns(
        ["#{branch_name} doesn't exist anymore on github"])
      post :create, params: branch_params
      flash[:alert].must_equal "#{branch_name} doesn't exist anymore on github"
    end

    describe "on success" do
      it "creates tracked branch" do
        post :create, params: branch_params
        TrackedBranch.last.branch_name.must_equal branch_name
      end

      it "creates a TestRun with correct attributes" do
        post :create, params: branch_params
        _test_run = TestRun.last

        _test_run.commit_sha.must_equal commit_sha
        _test_run.status.code.must_equal TestStatus::SETUP
      end

      it "does not create TestJobs" do
        post :create, params: branch_params

        TestRun.last.test_jobs.count.must_equal 0
      end

      it "displays flash notice" do
        post :create, params: branch_params
        flash[:notice].wont_be :empty?
      end
    end
  end

  describe "GET#new" do
    it "creates tracked branch" do
      GithubRepositoryManager.any_instance.stubs(:fetch_branches).
        returns([FactoryGirl.create(:tracked_branch, branch_name: branch_name)])
      get :new, params: branch_params
      TrackedBranch.last.branch_name.must_equal branch_name
    end
  end

  describe "DELETE#destroy" do
    let(:branch) { FactoryGirl.create(:tracked_branch) }
    let(:project) { branch.project }
    let(:project_id) { project.id }
    let(:owner) { project.user }
    before do
      sign_in owner, scope: :user
      request.env['HTTP_REFERER'] = 'a-random-path'
    end

    it "destroys branch if it belongs to current_project" do
      old_count = TrackedBranch.count
      delete :destroy, params: { project_id: project_id, id: branch.id }
      TrackedBranch.count.must_equal old_count - 1
    end

    it "flashes notice on success and redirects to project_path" do
      delete :destroy, params: { project_id: project_id, id: branch.id }

      flash[:notice].must_equal "#{branch.branch_name} branch was removed"
      assert_redirected_to project_path(project)
    end

    it "flashes alert on failure and redirects to project_branch_path" do
      TrackedBranch.any_instance.stubs(:destroy).returns(false)
      delete :destroy, params: { project_id: project_id, id: branch.id }

      flash[:alert].must_equal "Can't remove #{branch.branch_name} branch"
      assert_redirected_to project_branch_path(project, branch)
    end

    it "doesn't destroy branch if it doesn't belong to current_project" do
      old_count = TrackedBranch.count
      delete_branch = -> { 
        delete :destroy, params: { project_id: project_id + 1, id: branch.id } }
      delete_branch.must_raise ActiveRecord::RecordNotFound
      branch.reload
      TrackedBranch.count.must_equal old_count
    end
  end
end
