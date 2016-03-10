require 'test_helper'

class WebhooksControllerTest < ActionController::TestCase
  let(:tracked_branch) { FactoryGirl.create(:tracked_branch) }
  let(:project) { tracked_branch.project }
  let(:user) { project.user }
  let(:commit_sha) { "HEAD" }
  let(:filename_1) { "test/models/user_test.rb" }
  let(:filename_2) { "test/models/hello_test.rb" }

  before do
    tracked_branch
    project.update_column(:repository_provider, 'github')
    project.reload
    # Successful authorization for github
    @controller.stubs(:verify_request_from_github!).returns(nil)
  end

  describe "POST#github" do
    describe "delete event" do
      before do
        request.headers['HTTP_X_GITHUB_EVENT'] = 'delete'
        GithubRepositoryManager.any_instance.stubs(:project_file_names).returns(
          [filename_1, filename_2])
        post :github,
          { repository: { id: project.repository_id },
            ref_type: 'branch',
            ref: "#{tracked_branch.branch_name}" }
      end

      it "destroys the branch" do
        TrackedBranch.count.must_equal 0
      end
    end

    describe "push event" do
      let(:github_response) do
        Sawyer::Resource.new(Sawyer::Agent.new('api.example.com'),
          {
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
        )
      end
      before do
        request.headers['HTTP_X_GITHUB_EVENT'] = 'push'
        GithubRepositoryManager.any_instance.stubs(:sha_history).
          returns([github_response])

        GithubRepositoryManager.any_instance.stubs(:project_file_names).returns(
          [filename_1, filename_2])
        post :github, {
          head_commit: {
            id: commit_sha,
            message: 'Some commit messsage',
            timestamp: '2015-11-17 11:42:24 UTC',
            url: 'Some url',
            author: {
              name: 'Great Author',
              email: 'great@author.com',
              username: 'authorusername'
            },
            committer: {
              name: 'Great Committer',
              email: 'great@committer.com',
              username: 'committerusername'
            }
          },
          repository: { id: project.repository_id },
          ref: "refs/head/ispyropoulos/#{tracked_branch.branch_name}"
        }
        @testrun = TestRun.last
      end

      it "creates a test run with correct attributes" do
        @testrun.tracked_branch_id.must_equal tracked_branch.id
        @testrun.commit_sha.must_equal commit_sha
        @testrun.status.code.must_equal TestStatus::SETUP
      end

      it "responds with :ok" do
        assert_response :ok
      end
    end
  end
end
