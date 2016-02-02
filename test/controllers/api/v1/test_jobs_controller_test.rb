require 'test_helper'

class Api::V1::TestJobsControllerTest < ActionController::TestCase
  let(:project) { FactoryGirl.create(:project) }
  let(:application) { Doorkeeper::Application.new(owner: project) }
  let(:token) do
    token = MiniTest::Mock.new
    token.expect(:application, application)
    token.expect(:acceptable?, true, [Doorkeeper::OAuth::Scopes])
  end

  describe "PATCH#bind_next_batch" do
    describe "when there is no chunk in Redis queue" do
      before { Katana::Application.redis.flushall }
      it "returns and empty test_jobs array" do
        @controller.stub :doorkeeper_token, token do
          patch :bind_next_batch, default: { format: :json }
        end
        result = JSON.parse(response.body)
        result.count.must_equal 0
      end
    end

    describe "when the first element in the Redis queue is cancelled" do
      let(:cancelled_test_run) do
        FactoryGirl.build(:testributor_run, status: TestStatus::CANCELLED,
                         project: project)
      end
      let(:pending_test_run) do
        FactoryGirl.build(:testributor_run, status: TestStatus::QUEUED,
                         project: project)
      end

      before do
        10.times {
          cancelled_test_run.test_jobs.build(
            command: "ls", status: TestStatus::CANCELLED)
          pending_test_run.test_jobs.build(
            command: "ls", status: TestStatus::QUEUED)
        }
        Katanomeas.new(cancelled_test_run).assign_chunk_indexes_to_test_jobs
        Katanomeas.new(pending_test_run).assign_chunk_indexes_to_test_jobs
        cancelled_test_run.save!
        pending_test_run.save!

        assert_equal(
          Katana::Application.redis.lrange(project.test_runs_chunks_redis_key,-1,-1),
          ["#{cancelled_test_run.id}_0"])
      end

      it "tries the next chunk in queue" do
        @controller.stub :doorkeeper_token, token do
          patch :bind_next_batch, default: { format: :json }
        end
        result = JSON.parse(response.body)
        result.count.must_equal 1
        result.first["id"].must_equal pending_test_run.test_jobs.
          min{|j| j.chunk_index}.id
      end
    end

    describe "when the first element in the Redis queue is pending" do
      let(:pending_test_run) do
        FactoryGirl.build(:testributor_run, status: TestStatus::QUEUED,
                         project: project)
      end

      before do
        10.times {
          pending_test_run.test_jobs.build(
            command: "ls", status: TestStatus::QUEUED,
            old_avg_worker_command_run_seconds: 2)
        }
        Katanomeas.new(pending_test_run).assign_chunk_indexes_to_test_jobs
        pending_test_run.save!

        assert_equal(
          Katana::Application.redis.lrange(project.test_runs_chunks_redis_key,-1,-1),
          ["#{pending_test_run.id}_0"])
      end

      it "returns the test jobs of the retrieved chunk" do
        @controller.stub :doorkeeper_token, token do
          patch :bind_next_batch, default: { format: :json }
        end
        result = JSON.parse(response.body)
        result.count.must_equal 1
        result.first["id"].must_equal pending_test_run.test_jobs.
          min{|j| j.chunk_index}.id
      end

      it "updates the jobs' status to RUNNING" do
        @controller.stub :doorkeeper_token, token do
          patch :bind_next_batch, default: { format: :json }
        end
        pending_test_run.test_jobs.map{|j| j.status.code}.uniq.
          must_equal [TestStatus::QUEUED]
      end

      it "returns the cost_prediction for each job" do
        @controller.stub :doorkeeper_token, token do
          patch :bind_next_batch, default: { format: :json }
        end
        result = JSON.parse(response.body)
        result.map{|j| j["cost_prediction"].to_i}.must_equal [2]
      end
    end
  end
end
