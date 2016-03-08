require 'test_helper'

class HomepageFeatureTest < Capybara::Rails::TestCase
  let(:project) { FactoryGirl.create(:project) }
  let(:owner) { project.user }

  describe "when user is logged in" do
    before do
      branches = [
        {
          commit_sha: "344ads",
          status: TestStatus::QUEUED, name: 'queued-branch',
          commit_timestamp: 1.hour.ago
        },
        {
          commit_sha: "0f542",
          status: TestStatus::RUNNING, name: 'running-branch',
          commit_timestamp: 1.hour.ago
        },
        {
          commit_sha: "934ni",
          status: TestStatus::PASSED, name: 'passed-branch',
          commit_timestamp: 1.hour.ago
        },
        {
          commit_sha: "934ni",
          status: TestStatus::FAILED, name: 'failed-branch',
          commit_timestamp: 1.hour.ago
        },
        {
          commit_sha: "934ni",
          status: TestStatus::ERROR, name: 'error-branch',
          commit_timestamp: 1.hour.ago
        },
        {
          commit_sha: "a0acl",
          status: TestStatus::CANCELLED, name: 'cancelled-branch',
          commit_timestamp: 1.hour.ago
        }
      ]

      branches.each do |branch|
        project.tracked_branches.build({branch_name: branch[:name]}).test_runs.
          build(
            commit_sha: branch[:commit_sha],
            status: branch[:status],
            commit_timestamp: branch[:commit_timestamp],
            project: project
          )
      end

      project.save!
      login_as owner, scope: :user
    end

    it 'displays the branches along with statuses', js: true do
      visit root_path

      page.must_have_content "Queued"
      page.must_have_content "Passed"
      page.must_have_content "Failed"
      page.must_have_content "Error"
      page.must_have_content "Cancelled"
      page.must_have_content "Running"
    end
  end
end
