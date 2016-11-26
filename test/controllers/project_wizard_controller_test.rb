require 'test_helper'

class ProjectWizardControllerTest < ActionController::TestCase
  let(:user) { FactoryGirl.create(:user, projects_limit: 3) }

  before do
    sign_in user, scope: :user
    user.update_column(:projects_limit, 3)
  end

  describe "GET#show" do
    it "redirects to root_path if projects limit has been reached" do
      user.update_column(:projects_limit, 0)
      # id doesn't matter here. It could be anything
      VCR.use_cassette 'github_user' do
        get :show, params: { id: :select_repository }
      end

      flash[:alert].must_equal("You cannot add other projects as you have "\
        "reached your <strong>project limit</strong>. Please upgrade your plan.\n")
      assert_redirected_to root_path
    end

    it "redirects to the first step if project is missing from cookies" do
      get :show, params: { id: :configure }

      flash[:alert].must_equal "You need to select a repository first"
      assert_redirected_to project_wizard_path(:select_repository)
    end

    describe "when the requested step does not exist" do
      it "renders 404 Not Found" do
        ->{ get :show, params: { id: :some_non_existent_step } }.must_raise(
          ActionController::RoutingError)
      end
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
      sign_in user, scope: :user
      RepositoryManager.any_instance.stubs(:post_add_repository_setup).
        returns({ })
    end

    describe ":select_repository" do
      let(:current_step) { :select_repository }
      let(:next_step) { :configure }

      it "saves repo_name to Project is valid?" do
        put :update, params: first_step_params

        project = @controller.current_user.projects.last
        project.repository_name.must_equal repo_name
        project.repository_provider.must_equal "github"
        project.repository_owner.must_equal "pakallis"
        project.repository_id.must_equal 123
        project.repository_slug.must_equal "slug_sweet_slug"
      end

      it "redirects to next step if Project#valid?" do
        put :update, params: first_step_params

        assert_redirected_to project_wizard_path(next_step)
      end

      it "redirects to previous step and flashes if Project#invalid?" do
        request.env["HTTP_REFERER"] = project_wizard_path(current_step)
        VCR.use_cassette('github_user') do
          put :update, params: first_step_params.except(:repository_name)
        end

        flash[:alert].must_equal "Name can't be blank"
      end

      it "creates a new project and an oauth application and a worker group" do
        private_key = FactoryGirl.build(:worker_group).ssh_key_private
        request.env["HTTP_REFERER"] = project_wizard_path(current_step)
        put :update, params: { id: :select_repository, 
                               repository_provider: "bare_repo",
                               repository_name: "My generic repo",
                               private_key: private_key,
                               repository_url: "git://example.com/repo.git" }

        flash[:alert].must_equal nil
        assert_redirected_to project_wizard_path(next_step)

        project = Project.last
        project.name.must_equal "My generic repo"
        project.repository_provider.must_equal "bare_repo"
        project.oauth_applications.last.name.must_equal "My generic repo"
        project.worker_groups.last.ssh_key_private.must_equal private_key
      end

      it "flashes and error if bare_repo but no SSH key is provided" do
        request.env["HTTP_REFERER"] = project_wizard_path(current_step)
        VCR.use_cassette('github_user') do
          put :update, params: { id: :select_repository, 
                                 repository_provider: "bare_repo",
                                 repository_name: "My generic repo",
                                 repository_url: "git://example.com/repo.git" }
        end

        flash[:alert].must_equal "Ssh key private can't be blank"
      end

      it "flashes an error if SSH key is invalid and it does not create a project" do
        request.env["HTTP_REFERER"] = project_wizard_path(current_step)
        VCR.use_cassette 'github_user' do
          put :update, params: { id: :select_repository,
                                 repository_provider: "bare_repo",
                                 repository_name: "My generic repo",
                                 private_key: "invalid_key",
                                 repository_url: "git://example.com/repo.git" }
        end

        flash[:alert].must_equal "Ssh key private is invalid or passphrase protected"
        Project.count.must_equal 0
      end
    end

    describe ":configure" do
      let(:current_step) { :configure }
      let(:next_step) { :add_worker }

      before do
        put :update, params: first_step_params
      end

      it "saves _testributor_yml contents to ProjectFile if valid?" do
        put :update, 
          params: { id: current_step, testributor_yml: _testributor_yml }

        @controller.current_user.projects.last.project_files.
          where(path: ProjectFile::JOBS_YML_PATH).first.contents.
          must_equal( _testributor_yml)
      end

      it "redirects to next step if ProjectFile#valid?" do
        put :update, 
          params: { id: current_step, testributor_yml: _testributor_yml }

        assert_redirected_to project_wizard_path(next_step)
      end

      it "redirects to previous step and flashes if ProjectFile#invalid?" do
        request.env["HTTP_REFERER"] = project_wizard_path(current_step)
        put :update, 
          params: { id: current_step, testributor_yml: '' }

        flash[:alert].must_equal "Contents can't be blank"
        assert_redirected_to project_wizard_path(current_step)
      end
    end

    describe ":add_worker" do
      let(:current_step) { :add_worker }

      before do
        put :update, params: first_step_params
        put :update, 
          params: { id: :configure, testributor_yml: _testributor_yml }
      end

      it "removes Project id from cookies" do
        cookies[:wizard_project_id].to_i.must_equal(
          @controller.current_user.projects.last.id)
        put :update, params: { id: current_step }
        cookies[:wizard_project_id].must_equal nil
      end

      it "redirects to project path" do
        put :update, params: { id: current_step  }
        assert_redirected_to project_path(
          @controller.current_user.projects.first)
      end
    end
  end
end
