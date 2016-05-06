require 'test_helper'

class LiveUpdatesControllerTest < ActionController::TestCase
  describe "POST #subscribe" do
    let(:tracked_branch) { FactoryGirl.create(:tracked_branch) }
    let(:tracked_branch_from_another_user) do 
      FactoryGirl.create(:tracked_branch)
    end
    let(:subscription_params) do
      {
        uid: 'ArandomUID',
        subscriptions: {
          "Project" => tracked_branch.project.id,
          "TrackedBranch" => [tracked_branch.id, 
                              tracked_branch_from_another_user.id]
        }
      }
    end
    let(:user) { tracked_branch.project.user }

    before { sign_in :user, user }

    it "returns response in proper JSON format" do
      post :subscribe, subscription_params
      successful_subscriptions = JSON.
        parse(response.body)["successful_subscriptions"]
      successful_subscriptions["Project"].
        must_equal [tracked_branch.project.id]
      successful_subscriptions["TrackedBranch"].must_equal [tracked_branch.id]
    end
  end
end
