require 'test_helper'

class ProjectWizardControllerTest < ActionController::TestCase
  let(:user) { FactoryGirl.create(:user, projects_limit: 3) }

  before do
    sign_in :user, user
    user.update_column(:projects_limit, 3)
  end

  describe "GET#show" do
    it "redirects to root_path if projects limit has been reached" do
      user.update_column(:projects_limit, 0)
      # id doesn't matter here. It could be anything
      get :show, { id: :select_repository }

      flash[:alert].must_equal("You cannot add other projects as you have "\
        "reached your <strong>project limit</strong>. Please upgrade your plan.\n")
      assert_redirected_to root_path
    end

    it "redirects to the first step if project is missing from cookies" do
      get :show, { id: :configure }

      flash[:alert].must_equal "You need to select a repository first"
      assert_redirected_to project_wizard_path(:select_repository)
    end
  end

  describe "PUT#update" do
    let(:first_step_params) do
      { id: :select_repository, repository_name: repo_name, repository_provider: "github",
        repository_owner: "pakallis", repository_id: '123',
        repository_slug: "slug_sweet_slug" }
    end
    let(:_testributor_yml) do
      <<-YAML
        each:
          command: 'bin/rake test'
          pattern: 'test/models/*_test.rb'
      YAML
    end
    let(:repo_name) { "pakallis/hello" }

    before do
      sign_in :user, user
      RepositoryManager.any_instance.stubs(:post_add_repository_setup).
        returns(nil)
    end

    describe ":select_repository" do
      let(:current_step) { :select_repository }
      let(:next_step) { :configure }

      it "saves repo_name to Project is valid?" do
        put :update, first_step_params

        project = @controller.current_user.projects.last
        project.repository_name.must_equal repo_name
        project.repository_provider.must_equal "github"
        project.repository_owner.must_equal "pakallis"
        project.repository_id.must_equal 123
        project.repository_slug.must_equal "slug_sweet_slug"
      end

      it "redirects to next step if Project#valid?" do
        put :update, first_step_params

        assert_redirected_to project_wizard_path(next_step)
      end

      it "redirects to previous step and flashes if Project#invalid?" do
        request.env["HTTP_REFERER"] = project_wizard_path(current_step)
        put :update, first_step_params.except(:repository_name)

        flash[:alert].must_equal "Name can't be blank"
        assert_redirected_to project_wizard_path(current_step)
      end
    end

    describe ":configure" do
      let(:current_step) { :configure }
      let(:next_step) { :add_worker }

      before do
        put :update, first_step_params
      end

      it "saves _testributor_yml contents to ProjectFile if valid?" do
        put :update, { id: current_step, testributor_yml: _testributor_yml }

        @controller.current_user.projects.last.project_files.
          where(path: ProjectFile::JOBS_YML_PATH).first.contents.
          must_equal( _testributor_yml)
      end

      it "redirects to next step if ProjectFile#valid?" do
        put :update, { id: current_step, testributor_yml: _testributor_yml }

        assert_redirected_to project_wizard_path(next_step)
      end

      it "redirects to previous step and flashes if ProjectFile#invalid?" do
        request.env["HTTP_REFERER"] = project_wizard_path(current_step)
        put :update, { id: current_step, testributor_yml: '' }

        flash[:alert].must_equal "Contents can't be blank"
        assert_redirected_to project_wizard_path(current_step)
      end
    end

    describe ":add_worker" do
      let(:current_step) { :add_worker }

      before do
        put :update, first_step_params
        put :update, { id: :configure, testributor_yml: _testributor_yml }
      end

      it "removes Project id from cookies" do
        cookies[:wizard_project_id].must_equal(
          @controller.current_user.projects.last.id)
        put :update, { id: current_step }
        cookies[:wizard_project_id].must_equal nil
      end

      it "redirects to project path" do
        put :update, { id: current_step  }
        assert_redirected_to project_path(
          @controller.current_user.projects.first)
      end
    end
  end
end
