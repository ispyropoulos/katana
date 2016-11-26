require 'test_helper'

class UserInvitationsControllerTest < ActionController::TestCase
  let(:project) { FactoryGirl.create(:project) }
  let(:user) { project.user }

  before do
    project
    sign_in user, scope: :user
    request.env["HTTP_REFERER"] = "previous_path"
  end

  describe "POST#create" do
    it "creates a new invitation for the given email" do
      post :create, 
        params: { project_id: project.id, 
                  user_invitation: { email: "someone@example.com" } }
      flash[:notice].must_equal "Invitation will be sent shortly"
      UserInvitation.last.email.must_equal 'someone@example.com'
    end

    it "returns and error if invitation is not saved" do
      FactoryGirl.create(:user_invitation, email: 'someone@example.com',
                        project: project)

      post :create, 
        params: { project_id: project.id, 
                  user_invitation: { email: "someone@example.com" } }
      flash[:notice].must_be :nil?
      flash[:alert].must_equal "Email An invitation for this user already exists"
    end
  end

  describe "DELETE#destroy" do
    subject { FactoryGirl.create(:user_invitation, project: project) }

    it "destroys the invitation" do
      delete :destroy, params: { project_id: project.id, id: subject.id }
      flash[:notice].must_equal 'Invitation was cancelled'
      ->{ subject.reload }.must_raise ActiveRecord::RecordNotFound
    end
  end

  describe "POST#resend" do
    subject { FactoryGirl.create(:user_invitation, project: project) }

    it "sends an email for an existing invitation" do
      perform_enqueued_jobs do
        post :resend, params: { project_id: project.id, id: subject.id }
      end
      flash[:notice].must_equal "Invitation will be sent shortly"
      ActionMailer::Base.deliveries.last.body.to_s.must_match(subject.token)
    end
  end

  describe "GET#accept" do
    subject { FactoryGirl.create(:user_invitation, project: project) }

    describe "when the user is not logged in" do
      it "asks the user to login" do
        sign_out :user
        get :accept, params: { token: subject.token }
        flash[:alert].must_equal "You need to sign in or sign up before continuing."
      end
    end

    describe "when the user is logged in" do
      describe "but is already a member" do
        it "flashes a message" do
          get :accept, params: { token: subject.token }
          flash[:alert].must_equal "You are already a member of this project!"
        end
      end

      it "adds current_user to members" do
        subject.accepted_at.must_be :nil?
        user = FactoryGirl.create(:user)
        sign_in user, scope: :user
        get :accept, params: { token: subject.token }
        flash[:notice].must_equal "Welcome to #{project.name}"
        user.participating_projects.must_equal [project]
        subject.reload.accepted_at.wont_be :nil?
      end
    end
  end
end
