require 'test_helper'

class UsersApi::V1::CommitsControllerTest < ActionController::TestCase
  describe "GET#status" do
    let(:user) { FactoryGirl.create(:user, email: "dannydevito@example.com") }
    let(:user_token) do
      Doorkeeper::AccessToken.create(resource_owner_id: user.id)
    end
    let(:project) { FactoryGirl.create(:project, user: user) }
    let(:_test_run) do
      FactoryGirl.create(:testributor_run, project: project,
                         commit_sha: '1234567')
    end

    let(:_test_run_2) do
      FactoryGirl.create(:testributor_run, commit_sha: '543210')
    end

    describe "when no project is specified" do
      it "returns an error message" do
        get :status, params: { access_token: user_token.token, 
                               default: { format: 'json' },
                               id: _test_run.commit_sha }
        response.status.must_equal 404
        response.body.must_equal(
          "Project with name '' does not exist")
      end
    end

    describe "when the specified project does not exist" do
      it "returns an error message" do
        get :status, params: { access_token: user_token.token, 
                               default: { format: 'json' },
                               id: _test_run.commit_sha, 
                               project: 'some_non_existent_project' }
        response.status.must_equal 404
        response.body.must_equal(
          "Project with name 'some_non_existent_project' does not exist")
      end
    end

    describe "when :id (commit sha) is shorter than 6 characters" do
      it "returns an error message" do
        get :status, params: { access_token: user_token.token, 
                               default: { format: 'json' },
                               id: _test_run.commit_sha[0..2] }
        response.status.must_equal 400
        response.body.must_equal(
          'Specify a commit hash with at least the first 6 characters')
      end
    end

    describe "when the specified commit does not exist" do
      it "returns an error message" do
        get :status, params: { access_token: user_token.token, 
                               default: { format: 'json' },
                               id: 'non_existent_commit_sha', 
                               project: project.name }
        response.status.must_equal 404
        response.body.must_equal(
          'No Build found for the specified commit')
      end
    end

    describe "when the commit exists but not in the specified project" do
      it "still returns an error" do
        get :status, params: { access_token: user_token.token, 
                               default: { format: 'json' },
                               id: _test_run_2.commit_sha, 
                               project: project.name }
        response.status.must_equal 404
        response.body.must_equal(
          'No Build found for the specified commit')
      end
    end

    describe "when the specified project has a test run for the specified commit" do
      it "returns the status of the test run" do
        get :status, params: { access_token: user_token.token, 
                               default: { format: 'json' },
                               id: _test_run.commit_sha, 
                               project: project.name }
        response.status.must_equal 200
        JSON.parse(response.body).must_equal({"status" => "Setup"})
      end
    end
  end
end
