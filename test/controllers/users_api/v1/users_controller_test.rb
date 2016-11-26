require 'test_helper'

class UsersApi::V1::UsersControllerTest < ActionController::TestCase
  describe "#ensure_user!" do
    let(:project) { FactoryGirl.create(:project) }
    let(:application) do
      FactoryGirl.create(:doorkeeper_application, owner: project)
    end
    let(:worker_token) { application.access_tokens.create }

    it "returns 401 unauthorized when token does not have an resource_owner_id" do
      get :current, params: { access_token: worker_token.token,
                              default: { format: 'json' } }
      response.status.must_equal 401
    end
  end

  describe "GET#current" do
    let(:user) { FactoryGirl.create(:user, email: "dannydevito@example.com") }
    let(:user_token) do
      Doorkeeper::AccessToken.create(resource_owner_id: user.id)
    end

    it "returns the current user's data" do
      get :current, params: { access_token: user_token.token, 
                              default: { format: 'json' } }
      response.status.must_equal 200
      JSON.parse(response.body).must_equal(
        {"email" => "dannydevito@example.com"})
    end
  end
end
