require 'test_helper'

class ProjectParticipationsControllerTest < ActionController::TestCase
  let(:project) { FactoryGirl.create(:project) }
  let(:user) { FactoryGirl.create(:user) }

  before do
    project.members << user
  end

  describe "GET#index" do
    describe "when current_user is the owner" do
      before do
        sign_in project.user, scope: :user
      end

      it "lists all members" do
        get :index, params: { project_id: project.id }
        assigns(:participations).map(&:user_id).sort.
          must_equal [user.id, project.user_id].sort
      end
    end

    describe "when current_user is not the owner" do
      before do
        sign_in user, scope: :user
      end

      it "lists all members" do
        get :index, params: { project_id: project.id }
        assigns(:participations).map(&:user_id).sort.
          must_equal [user.id, project.user_id].sort
      end
    end
  end

  describe "GET#destroy" do
    before do
      request.env["HTTP_REFERER"] = 'back'
      sign_in project.user, scope: :user
    end

    it "allows the owner to remove members" do
      project.members.map(&:id).sort.
        must_equal [project.user_id, user.id].sort
      delete :destroy, params: { project_id: project.id,
                                 id: user.project_participations.first.id }
      project.members.reload.map(&:id).must_equal [project.user_id]
      user.reload # user should not be destroyed
    end

    it "not allows the owner to remove himself" do
      project.members.map(&:id).sort.
        must_equal [project.user_id, user.id].sort
      delete :destroy, params: { project_id: project.id,
                                 id: project.project_participations.
                                 where(user_id: project.user.id).first.id }
      assert_response 403
    end

    it "allows the non owner to remove himself" do
      sign_in user, scope: :user
      project.members.map(&:id).sort.
        must_equal [project.user_id, user.id].sort
      delete :destroy, params: { project_id: project.id,
                                 id: user.project_participations.first.id }
      project.members.reload.map(&:id).must_equal [project.user_id]
      user.reload # user should not be destroyed
    end

    it "does not allow non owner to remove the owner" do
      sign_in user, scope: :user
      project.members.map(&:id).sort.
        must_equal [project.user_id, user.id].sort
      delete :destroy, params: { project_id: project.id,
                                 id: project.project_participations.
                                 where(user_id: project.user.id).first.id }
      assert_response 403
    end
  end
end
