class Api::V1::TestJobsControllerTest < ActionController::TestCase
  let(:project) { FactoryGirl.create(:project) }
  let(:application) { Doorkeeper::Application.new(owner: project) }
  # ArgumentError: let 'test_run' cannot begin with 'test'. Please use another name.
  # That's what the _ is for :)
  let(:_test_run) do
    FactoryGirl.create(:test_run, project: project, status: TestStatus::PENDING)
  end
  let(:_test_jobs) do
    FactoryGirl.create_list(:test_job, 4, test_run: _test_run)
  end
  let(:token) do
    token = MiniTest::Mock.new
    token.expect(:application, application)
    token.expect(:acceptable?, true, [Doorkeeper::OAuth::Scopes])
  end

  before { _test_jobs }

  describe "PATCH#bind_next_pending" do
    it "returns a pending job and updates it's status to RUNNING" do
      _test_jobs[0..-2].each{|f| f.update_column(:status, TestStatus::RUNNING) }
      @controller.stub :doorkeeper_token, token do
        patch :bind_next_pending, default: { format: :json }
        result = JSON.parse(response.body)
        result["file_name"].must_equal _test_jobs[-1].file_name
        _test_jobs[-1].reload.status.must_equal TestStatus::RUNNING
      end
    end
  end
end