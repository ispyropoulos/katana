class DashboardControllerTest < ActionController::TestCase
  test "should prevent not logged users" do
    get :show
    assert_redirected_to new_user_session_path
  end

  test "should allow logged users" do
    sign_in :user, users(:dimitris)
    get :show
    assert_response :success
  end
end
