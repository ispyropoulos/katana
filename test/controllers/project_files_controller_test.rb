require 'test_helper'

class ProjectFilesControllerTest < ActionController::TestCase
  let(:project) { FactoryGirl.create(:project) }
  let(:user) { project.user }
  let(:registered_user) { FactoryGirl.create(:user) }

  before do
    project
    sign_in :user, user
    request.env["HTTP_REFERER"] = "previous_path"
  end

  describe "GET#index" do
    it "prevents not logged users" do
      sign_out :user
      get :index, project_id: project.id
      response.status.must_equal 302
      response.redirect_url.must_match /users\/sign_in/
    end

    it "redirects to testributor.yml" do
      contents = <<-YAML
        each:
          command: 'bin/rake test'
          pattern: 'test/models/*_test.rb'
      YAML
      testributor = project.project_files.
        create(path: "testributor.yml", contents: contents)
      project.project_files.create(path: "two", contents: "two contents")

      get :index, project_id: project.id

      assert_redirected_to project_file_path(project, testributor.id)
    end

    it "prevents not logged users" do
      sign_out :user
      sign_in :user, registered_user
      -> { get :index, project_id: project.id }.must_raise
        CanCan::AccessDenied
    end

    it "redirects to testributor.yml" do
      contents = <<-YAML
        each:
          command: 'bin/rake test'
          pattern: 'test/models/*_test.rb'
      YAML
      testributor = project.project_files.
        create(path: "testributor.yml", contents: contents)
      project.project_files.create(path: "two", contents: "two contents")

      get :index, project_id: project.id

      assert_redirected_to project_file_path(project, testributor.id)
    end
  end

  describe "POST#create" do
    let(:params) do
      { path: "config/database.yml",
        contents: "database info" }
    end

    it "creates the files with the specified params" do
      old_count = ProjectFile.count
      post :create, project_id: project.id, project_file: params
      flash[:alert].must_be :blank?
      ProjectFile.count.must_equal old_count + 1
      new_file = ProjectFile.last
      new_file.path.must_equal 'config/database.yml'
      new_file.contents.must_equal 'database info'
    end
  end

  describe "DELETE#destroy" do
    subject { FactoryGirl.create(:project_file, project: project) }
    before { subject }

    it "destroys the specified file" do
      old_count = ProjectFile.count
      delete :destroy, project_id: project.id, id: subject.id
      ProjectFile.count.must_equal old_count - 1
      ProjectFile.find_by(id: subject.id).must_be :nil?
    end

    it "doesn't destroy the file if it is the testributor.yml file" do
      old_count = ProjectFile.count
      ProjectFile.any_instance.
        stubs(:testributor_yml?).returns(true)
      delete :destroy, project_id: project.id, id: subject.id
      ProjectFile.count.must_equal old_count
    end

    it "won't destroy other project files" do
      other_project_file = FactoryGirl.create(:project_file)

      old_count = ProjectFile.count
      ->{ delete :destroy, project_id: project.id, id: other_project_file.id }.
        must_raise ActiveRecord::RecordNotFound
      ProjectFile.count.must_equal old_count
      ProjectFile.find_by(id: other_project_file.id).
        must_equal other_project_file
    end

    it "redirects to project_files_path(project)" do
      delete :destroy, project_id: project.id, id: subject.id
      assert_redirected_to project_files_path(project)
    end
  end

  describe "PUT#update" do
    subject { FactoryGirl.create(:project_file, project: project) }

    it "updates the specified record" do
      put :update, project_id: project.id, id: subject.id,
        project_file: { path: "the new path", contents: "the new contents" }
      flash[:alert].must_be :blank?

      subject.reload.path.must_equal 'the new path'
      subject.contents.must_equal 'the new contents'
    end
  end
end
