require 'test_helper'

class ProjectWizardControllerTest < ActionController::TestCase
  let(:project) { FactoryGirl.create(:project) }
  let(:user) { project.user }

  describe "GET#show" do
    before do
      user.update_column(:projects_limit, 2)
      sign_in :user, user
    end

    it "redirects to root_path if projects limit has been reached" do
      user.update_column(:projects_limit, 1)
      user.stubs(:github_client).returns(Octokit::Client)
      # id doesn't matter here. It could be anything
      get :show, { id: :add_project }

      flash[:alert].wont_be :empty?
      assert_redirected_to root_path
    end

    it "redirects to another step if a required param is missing" do
      user.stubs(:github_client).returns(Octokit::Client)
      # id doesn't matter here. It could be anything
      get :show, { id: :add_branches }

      flash[:alert].wont_be :empty?
      assert_redirected_to project_wizard_path(:add_project)
    end

    describe ":add_branches" do
      let(:step) { :add_branches }
      let(:first_step) { :add_project }

      it "redirects to :add_project if client is blank" do
        user.stubs(:github_client).returns(nil)
        get :show, { id: step }

        flash[:alert].wont_be :empty?
        assert_redirected_to project_wizard_path(first_step)
      end
    end
  end

  describe "PUT#update" do
    before do
      sign_in :user, user
      user.stubs(:github_client).returns(Octokit::Client)
    end

    describe ":add_project" do
      let(:repo_name) { "pakallis/hello" }
      let(:step) { :add_project }
      let(:next_step) { :add_branches }

      it "saves repo_name to ProjectWizard if valid?" do
        put :update, { id: step, repo_name: repo_name }
        @controller.current_user.project_wizard.repo_name.must_equal repo_name
      end

      it "redirects to next step if ProjectWizard#valid?" do
        put :update, { id: step, repo_name: repo_name }

        assert_redirected_to project_wizard_path(next_step)
      end

      it "redirects to previous step and flashes if ProjectWizard#invalid?" do
        request.env["HTTP_REFERER"] = project_wizard_path(step)
        put :update, { id: step, repo_name: nil }

        flash[:alert].wont_be :empty?
        assert_redirected_to project_wizard_path(step)
      end
    end

    describe ":add_branches" do
      let(:branch_names) { ["master", "new-feature"] }
      let(:current_step) { :add_branches }

      it "saves branch_names to ProjectWizard if valid?" do
        put :update, { id: current_step, branch_names: branch_names }
        @controller.current_user.project_wizard.branch_names.
          must_equal branch_names
      end

      it "redirects to next step if ProjectWizard#valid?" do
        put :update, { id: current_step, branch_names: branch_names }

        assert_redirected_to project_wizard_path(:configure_testributor)
      end

      it "redirects to previous step and flashes if ProjectWizard#invalid?" do
        request.env["HTTP_REFERER"] = project_wizard_path(current_step)
        put :update, { id: current_step, branch_names: nil }

        flash[:alert].wont_be :empty?
        assert_redirected_to project_wizard_path(current_step)
      end
    end

    describe ":configure_testributor" do
      let(:_testributor_yml) { "hello: world" }
      let(:current_step) { :configure_testributor }
      let(:next_step) { :select_technologies }

      it "saves _testributor_yml to ProjectWizard if valid?" do
        put :update, { id: current_step, testributor_yml: _testributor_yml }
        @controller.current_user.project_wizard.
          testributor_yml.must_equal _testributor_yml
      end

      it "redirects to next step if ProjectWizard#valid?" do
        put :update, { id: current_step, testributor_yml: _testributor_yml }

        assert_redirected_to project_wizard_path(next_step)
      end

      it "redirects to previous step and flashes if ProjectWizard#invalid?" do
        request.env["HTTP_REFERER"] = project_wizard_path(current_step)
        put :update, { id: current_step, testributor_yml: '' }

        flash[:alert].wont_be :empty?
        assert_redirected_to project_wizard_path(current_step)
      end
    end

    describe ":select_technologies" do
      let(:current_step) { :select_technologies }
      let(:docker_image_id) { 1 }
      let(:next_step) { :wicked_finish }
      let(:project_wizard) do
        FactoryGirl.create(:project_wizard, user: user)
      end

      before do
        ProjectWizard.any_instance.stubs(:to_project).returns(Project.new)
        ProjectWizard.any_instance.
          stubs(:create_branches).returns([TrackedBranch.new])
        project_wizard
      end

      it "destroys ProjectWizard" do
        skip true
        project_wizard.stubs(:to_project).returns(Project.new)
        project_wizard.stubs(:create_branches).returns([TrackedBranch.new])
        put :update,
          { id: current_step,
            project_wizard: { docker_image_id: docker_image_id } }

        @controller.current_user.project_wizard.must_equal nil
      end

      it "redirects to next step if ProjectWizard#valid?" do
        put :update,
          { id: current_step,
            project_wizard: { docker_image_id: docker_image_id } }
        assert_redirected_to project_wizard_path(next_step)
      end

      it "redirects to previous step and flashes if ProjectWizard#invalid?" do
        request.env["HTTP_REFERER"] = project_wizard_path(current_step)
        put :update,
          { id: current_step,
            project_wizard: { docker_image_id: '' } }

        flash[:alert].wont_be :empty?
        assert_redirected_to project_wizard_path(current_step)
      end
    end
  end
end
