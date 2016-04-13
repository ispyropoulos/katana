require 'test_helper'

class WorkerGroupsControllerTest < ActionController::TestCase
  let(:project) { FactoryGirl.create(:project) }
  let(:worker_group) { FactoryGirl.create(:worker_group) }
  let(:user) { FactoryGirl.create(:user) }

  describe 'when registered users visit the page' do
    before do
      project.worker_groups << worker_group
      request.env["HTTP_REFERER"] = "previous_path"
      sign_in :user, user
    end

    describe 'POST#create' do
      it 'allows if member of the project' do
        project.members << user

        post :create, { project_id: project.id }
        assert_response 302
      end

      it 'does not allow if not member of the project' do
        -> { post :create, { project_id: project.id } }.must_raise ActiveRecord::RecordNotFound
      end
    end

    describe 'PUT#update' do
      it 'allows if member of the project' do
        project.members << user

        xhr :put, :update,
          { project_id: project.id,
            id: project.worker_groups.first.id,
            worker_group: worker_group.attributes }
        assert_response 200
      end

      it 'does not allow if not member of the project' do
        -> {
          xhr :put, :update,
            { project_id: project.id,
              id: project.worker_groups.first.id,
              worker_group: worker_group.attributes }
        }.must_raise ActiveRecord::RecordNotFound
      end
    end

    describe 'POST#destroy' do
      before do
        project.oauth_applications << worker_group.oauth_application
      end

      it 'allows if member of the project' do
        project.members << user

        post :destroy, {
          project_id: project.id,
          id: project.worker_groups.first.id,
          worker_group: worker_group.attributes }
        assert_response 302
      end

      it 'does not allow if not member of the project' do
        -> { post :destroy,
          project_id: project.id,
          id: project.worker_groups.first.id,
          worker_group: worker_group.attributes
        }.must_raise ActiveRecord::RecordNotFound
      end
    end

    describe 'POST#reset_keys' do
      before do
        project.oauth_applications << worker_group.oauth_application
      end

      it 'does not allow if not member of the project' do
        -> { post :reset_ssh_key,
          project_id: project.id,
          id: project.worker_groups.first.id,
          worker_group: worker_group.attributes
        }.must_raise ActiveRecord::RecordNotFound
      end
    end
  end
end
