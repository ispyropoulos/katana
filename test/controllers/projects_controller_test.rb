require 'test_helper'

class ProjectsControllerTest < ActionController::TestCase
  let(:project) { FactoryGirl.create(:project) }
  let(:owner) { project.user }
  let(:language) { FactoryGirl.create(:docker_image, :language) }
  let(:technology) { FactoryGirl.create(:docker_image) }

  before do
    request.env["HTTP_REFERER"] = "previous_path"
    sign_in :user, owner
  end

  describe "PATCH#update" do
    it "updates docker_image_id when Project#valid?" do
      project_params = {
        id: project.id, project: { docker_image_id: language.id } }
      patch :update, project_params

      project.reload
      project.docker_image_id.must_equal language.id
    end

    it "updates technology_ids when Project#valid?" do
      project_params = {
        id: project.id,
        project: {
          docker_image_id: language.id,
          technology_ids: [technology.id]}
      }
      patch :update, project_params

      project.reload
      project.technology_ids.must_equal [technology.id]
    end
  end

  describe "DELETE#destroy" do
    it "doesn't destroy the project if user is not the owner" do
      member = FactoryGirl.create(:user)
      project.members << member
      sign_in :user, member

      -> { delete :destroy, { id: project.id } }.
        must_raise ActiveRecord::RecordNotFound

      Project.count.must_equal 1
    end

    it "destroys the project if user is the owner" do
      Octokit::Client.any_instance.stubs(:remove_hook).returns(1)
      delete :destroy, { id: project.id }

      Project.count.must_equal 0
    end

    it "deletes the github webhook if project was destroyed" do
      Octokit::Client.any_instance.expects(:remove_hook).once
      delete :destroy, { id: project.id }
    end

    it "doesn't delete the github webhook if project wasn't destroyed" do
      Project.any_instance.stubs(:destroy).returns(false)
      Octokit::Client.any_instance.expects(:remove_hook).never
      delete :destroy, { id: project.id }
    end
  end
end
