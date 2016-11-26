require 'test_helper'

class DashboardControllerTest < ActionController::TestCase
  describe "#index" do
    let(:user_with_project) { FactoryGirl.create(:user, admin: false) }
    let(:project) { FactoryGirl.create(:project, user: user_with_project) }
    let(:user_without_project) { FactoryGirl.create(:user, admin: false) }

    describe "when user has a project" do
      before do
        project
        sign_in user_with_project, scope: :user
      end

      it "returns 200" do
        get :index, params: { id: user_with_project.id }

        response.status.must_equal 200
      end
    end

    describe "when user has no project" do
      before { sign_in user_without_project, scope: :user }

      it "returns 302" do
        get :index, params: { id: user_without_project.id }

        response.status.must_equal 302
      end

      describe "but cannot create any projects" do
        before do
          user_without_project.update_column(:projects_limit, 0)
        end

        it "flashes an error and does not redirect" do
          get :index, params: { id: user_without_project.id }
          flash[:alert].must_equal("You can't create any projects. <a href=\"mailto:support@testributor.com\">Contact us</a> if you think this is a mistake.")

          response.status.must_equal 200
        end
      end
    end
  end
end
