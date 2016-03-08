require 'test_helper'

class TestRunStatusNotificationFeatureTest < Capybara::Rails::TestCase
  let(:_test_job) { FactoryGirl.create(:testributor_job) }
  let(:_test_run) { _test_job.test_run }
  let(:branch) { _test_run.tracked_branch }
  let(:project) { _test_run.project }
  let(:owner) { project.user }

  before do
    Octokit::Client.any_instance.stubs(:create_status).returns(nil)

    login_as owner, scope: :user
  end

  describe 'retrying a test triggers a post action to github' do
    describe 'when we rerty a test run' do
      before do
        _test_job.update_column(:status, TestStatus::PASSED)
        _test_job.reload
        _test_run.update_column(:status, TestStatus::PASSED)
        _test_run.reload

        visit project_branch_test_runs_path(project, branch)
      end

      it "creates a notification when user retries a test run", js: true do
         VcsStatusNotifier.expects(:perform_later).once
         find(".btn-primary", text: "Retry").click
      end
    end
  end

  describe 'when we create a new run' do
    let(:_test_run) { FactoryGirl.create(:testributor_run) }
    let(:owner) { _test_run.project.user }
    let(:_test_job) { FactoryGirl.create(:testributor_job, test_run: _test_run) }
    let(:branch_name) { 'master' }
    let(:commit_sha) { 'a3e2de2r' }
    let(:branch_github_response) do
      [Sawyer::Resource.new(Sawyer::Agent.new('api.example.com'),
          {
            name: branch_name,
            sha: commit_sha,
            commit: {
              message: 'Some commit messsage',
              html_url: 'Some url',
              author: {
                name: 'Great Author',
                email: 'great@author.com',
                login: 'authorlogin'
              },
              committer: {
                name: 'Great Committer',
                email: 'great@committer.com',
                date: DateTime.current,
                login: 'committerlogin'
              }
            },
              committer: {
                login: 'committerlogin'
            },
              author: {
                login: 'authorlogin'
            }
          }
        )
      ]
    end

    before do
      _test_job.test_run.project.
        project_files << FactoryGirl.create(:project_file, path: ProjectFile::JOBS_YML_PATH)
      GithubRepositoryManager.any_instance.stubs(:sha_history).returns(branch_github_response)
      login_as owner, scope: :user
    end

    describe 'when a user clicks add a new run button' do
      before do
        visit project_branch_test_runs_path(project_id: _test_run.project.id,
          branch_id: _test_run.tracked_branch.id)
      end

      it 'turns all previous queued test_jobs to cancelled', js: true do
        perform_enqueued_jobs do
          VCR.use_cassette 'github_status_notification', match_requests_on: [:host, :method] do
            page.find('a[action="create"]').click
          end
        end
      end
    end
  end
end
