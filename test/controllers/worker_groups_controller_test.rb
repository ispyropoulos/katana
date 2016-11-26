require 'test_helper'

class WorkerGroupsControllerTest < ActionController::TestCase
  let(:project) { FactoryGirl.create(:project) }
  let(:worker_group) { FactoryGirl.create(:worker_group) }
  let(:user) { FactoryGirl.create(:user) }

  describe 'when registered users visit the page' do
    before do
      project.worker_groups << worker_group
      request.env["HTTP_REFERER"] = "previous_path"
      sign_in user, scope: :user
    end

    describe 'POST#create' do
      it 'allows if member of the project and flashes success' do
        project.members << user

        post :create, params: { project_id: project.id }
        assert_response 302
        flash[:alert].must_equal nil
        flash[:notice].must_equal "A Worker Group has been created."
      end

      it 'does not allow if not member of the project' do
        -> { post :create, params: { project_id: project.id } }.
          must_raise ActiveRecord::RecordNotFound
      end

      it "flashes validation errors" do
        project.members << user

        post :create, params: { project_id: project.id,
                                worker_group: { friendly_name: "" } }
        assert_response 302
        flash[:alert].must_equal "Friendly name can't be blank"
        flash[:notice].must_equal nil
      end
    end

    describe 'PUT#update' do
      it 'allows if member of the project' do
        project.members << user

        put :update, params: { project_id: project.id,
                               id: project.worker_groups.first.id,
                               worker_group: worker_group.attributes }
        assert_response 302
        flash[:alert].must_equal nil
        flash[:notice].must_equal "Successfully updated worker group"
      end

      it 'does not allow if not member of the project' do
        -> {
          put :update, params: { project_id: project.id,
                                 id: project.worker_groups.first.id,
                                 worker_group: worker_group.attributes }
        }.must_raise ActiveRecord::RecordNotFound
      end

      it "flashes validation errors" do
        project.members << user

        put :update, params: { project_id: project.id,
                               id: project.worker_groups.first.id,
                               worker_group: { friendly_name: '' } }
        assert_response 302
        flash[:alert].must_equal "Friendly name can't be blank"
        flash[:notice].must_equal nil
      end
    end

    describe 'POST#destroy' do
      before do
        project.oauth_applications << worker_group.oauth_application
      end

      it 'allows if member of the project' do
        project.members << user

        post :destroy, params: { project_id: project.id,
                                 id: project.worker_groups.first.id,
                                 worker_group: worker_group.attributes }
        assert_response 302
      end

      it 'does not allow if not member of the project' do
        -> { post :destroy, params: { project_id: project.id,
                                      id: project.worker_groups.first.id,
                                      worker_group: worker_group.attributes }
        }.must_raise ActiveRecord::RecordNotFound
      end

      it "does not store 'POST' urls in redirect_to_url" do
        cookies[:redirect_to_url] = "some_url"

        project.members << user
        post :destroy, params: { project_id: project.id,
                                 id: project.worker_groups.first.id,
                                 worker_group: worker_group.attributes }

        assert_response 302
        cookies[:redirect_to_url].must_equal "some_url"
      end
    end

    describe 'POST#reset_keys' do
      before do
        project.oauth_applications << worker_group.oauth_application
      end

      it 'does not allow if not member of the project' do
        -> { post :reset_ssh_key, params: { project_id: project.id,
                                            id: project.worker_groups.first.id,
                                            worker_group: worker_group.attributes }
        }.must_raise ActiveRecord::RecordNotFound
      end
    end
  end
end
