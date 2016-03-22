require 'test_helper'

class DashboardControllerTest < ActionController::TestCase
  describe "#index" do
    let(:user_with_project) { FactoryGirl.create(:user, admin: false) }
    let(:project) { FactoryGirl.create(:project, user: user_with_project) }
    let(:user_without_project) { FactoryGirl.create(:user, admin: false) }

    describe "when user has a project" do
      before do
        project
        sign_in :user, user_with_project
      end

      it "returns 200" do
        get :index, id: user_with_project.id

        response.status.must_equal 200
      end
    end

    describe "when user has no project" do
      before { sign_in :user, user_without_project }

      it "returns 302" do
        get :index, id: user_without_project.id

        response.status.must_equal 302
      end
    end
  end
end
