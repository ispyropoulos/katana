class DashboardControllerTest < ActionController::TestCase
  let(:user) { FactoryGirl.create(:user) }

  describe "GET#index" do
    it "should prevent not logged users" do
      get :index
      assert_redirected_to new_user_session_path
    end

    it "should allow logged users" do
      sign_in :user, user
      get :index
      assert_response :success
    end
  end

end
