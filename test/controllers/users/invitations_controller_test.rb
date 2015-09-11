require 'test_helper'
 
class Users::InvitationsControllerTest < ActionController::TestCase
  describe "GET#new" do
    let(:user) { FactoryGirl.create(:user) }
    before { sign_in :user, user }

    it "does not allow non owners to create invitations" do
      get :new
      response.status.must_equal 302
      flash[:alert].must_equal "Only organization owners can send invitations!"
    end

    it "allows organization owners to create invitations" do
      FactoryGirl.create(:organization, user: user)
      get :new
      response.status.must_equal 200
      flash[:alert].must_equal nil
    end
  end

  describe "POST#create" do
    let(:user) { FactoryGirl.create(:user) }
    before { sign_in :user, user }

    it "does not allow non owners to create invitations" do
      post :create, user: { email: "johndoe@example.com" }
      flash[:alert].must_equal "Only organization owners can send invitations!"
      ActionMailer::Base.deliveries.must_be_empty
    end

    it "allows organization owners to create invitations" do
      FactoryGirl.create(:organization, user: user)
      post :create, user: { email: "johndoe@example.com" }
      flash[:alert].must_equal nil
      ActionMailer::Base.deliveries.first.subject.must_equal "Invitation instructions"
    end
  end

  describe "PUT#update" do
    let(:organization) { FactoryGirl.create(:organization) }

    before do
      @user = User.invite!({ :email => "new_user@example.com" }, organization)
      @token = @user.raw_invitation_token
    end

    it "assigns the user accepting an invitation to the inviting organization" do
      @user.participating_organizations.must_equal []
      put :update, user: { invitation_token: @token, password: '12345678',
                           password_confirmation: '12345678' }
      @user.reload.invitation_accepted_at.wont_be_nil
      @user.invitation_token.must_be_nil
      @user.participating_organizations.must_equal [organization]
      organization.participating_users.must_equal [@user]
    end
  end
end
