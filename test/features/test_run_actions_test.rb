require 'test_helper'

class TestRunActionsFeatureTest < Capybara::Rails::TestCase
  let(:_test_run) { FactoryGirl.create(:testributor_run) }
  let(:owner) { _test_run.project.user }
  let(:_test_job) { FactoryGirl.create(:testributor_job, test_run: _test_run) }
  let(:branch_name) { 'master' }
  let(:commit_sha) { 'a3e2de2r' }
  let(:branch_github_response) do
    commit_github_response =
      Sawyer::Resource.new(Sawyer::Agent.new('api.example.com'),
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
    GithubRepositoryManager.any_instance.stubs(:sha_history).returns([
      commit_github_response,
      commit_github_response,
      commit_github_response])
  end

  before do
    _test_job.test_run.project.
      project_files << FactoryGirl.create(:project_file, path: ProjectFile::JOBS_YML_PATH)
    TrackedBranch.any_instance.stubs(:from_github).returns(branch_github_response)
    login_as owner, scope: :user
  end

  describe 'when a user visits the test_runs index' do
    it 'displays the retry action when the run is passed' do
      _test_run.update_column(:status, TestStatus::PASSED)
      visit project_branch_test_runs_path(
        project_id: _test_run.project.id,
        branch_id: _test_run.tracked_branch.id)
      page.must_have_content('Retry')
    end

    it 'displays the retry action when the run is errored' do
      _test_run.update_column(:status, TestStatus::ERROR)
      visit project_branch_test_runs_path(
        project_id: _test_run.project.id,
        branch_id: _test_run.tracked_branch.id)
      page.must_have_content('Retry')
    end

    it 'displays the retry action when the run is failed' do
      _test_run.update_column(:status, TestStatus::FAILED)
      visit project_branch_test_runs_path(
        project_id: _test_run.project.id,
        branch_id: _test_run.tracked_branch.id)
      page.must_have_content('Retry')
    end

    it 'does not display the retry action when the run is queued' do
      _test_run.update_column(:status, TestStatus::QUEUED)
      visit project_branch_test_runs_path(
        project_id: _test_run.project.id,
        branch_id: _test_run.tracked_branch.id)
      page.wont_have_content('Retry')
    end

    it 'does not display the retry action when the run is running' do
      _test_run.update_column(:status, TestStatus::RUNNING)
      visit project_branch_test_runs_path(
        project_id: _test_run.project.id,
        branch_id: _test_run.tracked_branch.id)
      page.wont_have_content('Retry')
    end

    it 'does not display the retry action when the run is cancelled' do
      _test_run.update_column(:status, TestStatus::CANCELLED)
      visit project_branch_test_runs_path(
        project_id: _test_run.project.id,
        branch_id: _test_run.tracked_branch.id)
      page.wont_have_content('Retry')
    end

    it 'displays the cancel action' do
      visit project_branch_test_runs_path(
        project_id: _test_run.project.id,
        branch_id: _test_run.tracked_branch.id)
      page.must_have_content('Cancel')
    end
  end

  describe 'when a user clicks on delete button' do
    before do
      visit project_branch_test_runs_path(project_id: _test_run.project.id,
        branch_id: _test_run.tracked_branch.id)
    end

    it 'must delete all test_jobs' do
      _test_run.test_jobs.pluck(:id).must_equal [_test_job.id]
      page.find('td .btn.btn-danger', text: "Cancel").click
      page.must_have_selector("#test-run-#{_test_run.id}", text: "Cancelled")
      TestRun.cancelled.count.must_equal 1
    end
  end

  describe 'when a user clicks add a new run button' do
    before do
      visit project_branch_test_runs_path(project_id: _test_run.project.id,
        branch_id: _test_run.tracked_branch.id)
    end

    it 'turns all previous queued test_jobs to cancelled', js: true do
      page.must_have_content 'Queued'
      page.find('a[action="create"]').click
      _test_run.reload.status.code.must_equal TestStatus::CANCELLED
      _test_run.test_jobs.pluck(:status).uniq.must_equal [TestStatus::CANCELLED]
    end
  end
end
