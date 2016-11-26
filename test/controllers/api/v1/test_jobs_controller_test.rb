require 'test_helper'

class Api::V1::TestJobsControllerTest < ActionController::TestCase
  let(:project) { FactoryGirl.create(:project) }
  let(:application) { Doorkeeper::Application.new(owner: project) }
  # ArgumentError: let 'test_run' cannot begin with 'test'. Please use another name.
  # That's what the _ is for :)
  let(:_test_run) do
    FactoryGirl.create(:testributor_run, :queued, project: project)
  end
  let(:_test_jobs) do
    FactoryGirl.create_list(:testributor_job, 4, test_run: _test_run)
  end
  let(:token) do
    token = MiniTest::Mock.new
    token.expect(:application, application)
    token.expect(:acceptable?, true, [Doorkeeper::OAuth::Scopes])
  end

  before { _test_jobs }

  describe "PATCH#bind_next_batch" do
    it "returns queued jobs and updates it's status to RUNNING" do
      # all jobs on the same chunk, only one has QUEUED status
      _test_jobs.each{|j| j.update_columns(chunk_index: 0,
                                           worker_uuid: "alive_worker_uuid")}
      _test_jobs[0..-2].each{|f| f.update_column(:status, TestStatus::RUNNING)}

      @controller.stub :doorkeeper_token, token do
        # the request will also make this worker active
        request.env['HTTP_WORKER_UUID'] = 'alive_worker_uuid'
        patch :bind_next_batch, params: { default: { format: 'json' } }
        result = JSON.parse(response.body)
        result.count.must_equal 1
        result.first["command"].must_equal _test_jobs[-1].command
        _test_jobs[-1].reload.status.code.must_equal TestStatus::RUNNING
      end
    end

    it "returns inactive-worker jobs and updates their worker_uuid" do
      _test_jobs.each{|f| f.update_columns(status: TestStatus::RUNNING)}
      # These are in RUNNING status but they will be returned because their
      # worker is not in the "active_workers" list of this project
      _test_jobs[0..-2].each{|f| f.update_column(:worker_uuid, "dead_worker_uuid")}
      # "alive_worker_uuid" will be added to the active workers as soon as the
      # request is sent.
      _test_jobs.last.update_column(:worker_uuid, "alive_worker_uuid")

      @controller.stub :doorkeeper_token, token do
        # the request will also make this worker active
        request.env['HTTP_WORKER_UUID'] = 'alive_worker_uuid'
        patch :bind_next_batch, params: { default: { format: 'json' } }
        result = JSON.parse(response.body)
        result.count.must_equal 3
        _test_jobs[0..-2].each(&:reload).map(&:worker_uuid).uniq.
          must_equal ['alive_worker_uuid']
        _test_jobs[0..-2].map{|j| j.status.code}.uniq.
          must_equal [TestStatus::RUNNING]
      end
    end

    it "updates active-worker jobs worker_uuid to the worker's uuid" do
      _test_jobs[0..-2].each{|f| f.update_column(:status, TestStatus::RUNNING)}
      @controller.stub :doorkeeper_token, token do
        request.env['HTTP_WORKER_UUID'] = 'this_is_a_worker_uuid'
        patch :bind_next_batch, params: { default: { format: 'json' } }
        result = JSON.parse(response.body)
        _test_jobs.each(&:reload).map(&:worker_uuid).compact.uniq.
          must_equal ['this_is_a_worker_uuid']
      end
    end

    it "does not count incosistent state jobs in workload" do
      terminal_state_test_run =
        FactoryGirl.create(:testributor_run, project: project)

      # Incosistent jobs (non terminal state jobs in terminal state run)
      FactoryGirl.create_list(:testributor_job, 10,
        test_run: terminal_state_test_run, status: TestStatus::QUEUED)

      # Set the TestRun to inconsistent state
      terminal_state_test_run.update_column(:status, TestStatus::PASSED)

      @controller.stub :doorkeeper_token, token do
        patch :bind_next_batch, params: { default: { format: 'json' } }
        result = JSON.parse(response.body)
        result.count.must_equal 4
      end
    end

    describe "when there are other running test jobs on other projects" do
      let(:irrelevant_project) { FactoryGirl.create(:project) }
      let(:irrelevant_test_run) do
        FactoryGirl.create(:testributor_run, project: irrelevant_project)
      end
      let(:irrelevant_test_job) do
        FactoryGirl.create(:testributor_job, test_run: irrelevant_test_run,
          status: TestStatus::RUNNING, worker_uuid: "irrelevant_worker")
      end

      before { irrelevant_test_job }

      it "does not return test jobs of irrelevant test runs (fixed bug)" do
        _test_jobs.each{|j| j.update_columns(chunk_index: 0,
                                            worker_uuid: "alive_worker_uuid")}

        @controller.stub :doorkeeper_token, token do
          # the request will also make this worker active
          request.env['HTTP_WORKER_UUID'] = 'alive_worker_uuid'
          patch :bind_next_batch, params: { default: { format: 'json' } }
          result = JSON.parse(response.body)
          result.map{|r| r["id"]}.wont_include irrelevant_test_job.id
          result.count.must_equal 4
        end
      end
    end

    it "returns the cost_prediction for each job" do
      TestJob.update_all(old_avg_worker_command_run_seconds: 2)
      @controller.stub :doorkeeper_token, token do
        patch :bind_next_batch, params: { default: { format: 'json' } }
        result = JSON.parse(response.body)
        result.count.must_equal 4
        result.map{|j| j["cost_prediction"].to_i}.must_equal [2,2,2,2]
      end
    end

    describe "when there are no pending jobs and the provider is 'bare_repo'" do
      let(:oldest_pending_setup_run) do
        FactoryGirl.create(:testributor_run, project: project,
                           status: TestStatus::SETUP, created_at: 3.minutes.ago)
      end

      let(:newest_pending_setup_run) do
        FactoryGirl.create(:testributor_run, project: project,
                           status: TestStatus::SETUP, created_at: 1.minutes.ago)
      end

      before do
        TestJob.delete_all
        project.update_column(:repository_provider, "bare_repo")
        oldest_pending_setup_run
        newest_pending_setup_run
      end

      it 'returns the oldest pending "Setup" job' do
        result = nil
        @controller.stub :doorkeeper_token, token do
          request.env['HTTP_WORKER_UUID'] = 'alive_worker_uuid'
          patch :bind_next_batch, params: { default: { format: 'json' } }
          result = JSON.parse(response.body)
        end

        result["test_run"].must_equal({
          "id" => oldest_pending_setup_run.id,
           "commit_sha" => oldest_pending_setup_run.commit_sha
        })
        result["testributor_yml"].must_equal ''
        result["type"].must_equal 'setup'

        oldest_pending_setup_run.reload.
          setup_worker_uuid.must_equal("alive_worker_uuid")
      end

      describe "when there is no Setup Job too" do
        before do
          TestRun.where(status: TestStatus::SETUP).
            update_all(status: TestStatus::PASSED)
        end

        it "returns an empty array of TestJobs" do
          result = nil
          @controller.stub :doorkeeper_token, token do
            request.env['HTTP_WORKER_UUID'] = 'alive_worker_uuid'
            patch :bind_next_batch, params: { default: { format: 'json' } }
            result = JSON.parse(response.body)
          end

          result.must_equal []
        end
      end
    end
  end

  describe "PATCH#batch_update" do
    let(:_test_job_json) do
      { command: "rspec spec/validators/redirect_uri_validator_spec.rb",
        cost_prediction: 23,
        sent_at_seconds_since_epoch: 1454339875,
        worker_in_queue_seconds: 20,
        worker_command_run_seconds: 20,
        test_run: { commit_sha: "21731d02b766f6978bf3b2bf69137338b081fcaf", id: _test_run.id},
        result: "result",
        status: TestStatus::PASSED }.to_json
    end
    let(:report_time) { 3.hours.ago }

    before do
      _test_jobs.each do |j|
        j.update(status: TestStatus::RUNNING,
          sent_at:  Date.new(2015, 01,01).beginning_of_day,
          worker_in_queue_seconds: 10, worker_command_run_seconds: 10,
          reported_at: report_time)
      end
    end

    it "does not update sent_at if already set" do
      @controller.stub :doorkeeper_token, token do
        patch :batch_update, 
          params: { default: { format: 'json' }, 
                    jobs: Hash[_test_jobs.map{|j| [j.id, _test_job_json]}]  }
      end

      _test_jobs.last.reload.sent_at.must_equal Date.new(2015, 01,01).beginning_of_day
    end

    it "does not update worker_in_queue_seconds if already set" do
      @controller.stub :doorkeeper_token, token do
        patch :batch_update, 
          params: { default: { format: 'json' },
                    jobs: Hash[_test_jobs.map{|j| [j.id, _test_job_json]}] }
      end

      _test_jobs.last.reload.worker_in_queue_seconds.must_equal 10
    end

    it 'does not send the TestJobUpdate event twice' do
      # ((Test job count) x2 + 1) for the TestRun
      Broadcaster.expects(:publish).with(
        _test_jobs.last.test_run.redis_live_update_resource_key,
        instance_of(Hash)
      ).times(9)

      @controller.stub :doorkeeper_token, token do
        patch :batch_update, 
          params: { default: { format: 'json' },
                    jobs: Hash[_test_jobs.map{|j| [j.id, _test_job_json]}] }
      end
    end


    it "does not update worker_command_run_seconds if already set" do
      @controller.stub :doorkeeper_token, token do
        patch :batch_update, 
          params: { default: { format: 'json' },
                    jobs: Hash[_test_jobs.map{|j| [j.id, _test_job_json]}] }
      end

      _test_jobs.last.reload.worker_command_run_seconds.must_equal 10
    end

    it "does not update reported_at if already set" do
      @controller.stub :doorkeeper_token, token do
        patch :batch_update, 
          params: { default: { format: 'json' },
                    jobs: Hash[_test_jobs.map{|j| [j.id, _test_job_json]}] }
      end

      _test_jobs.last.reload.reported_at.to_i.must_equal report_time.to_i
    end

    # Workers that became inactive for some reason might try to update the jobs
    # after being reassigned to another worker. We simply ignore the old worker.
    it "does not update jobs assigned to another worker" do
      _test_jobs.each{|j| j.update_columns(worker_uuid: "the_original_uuid",
                                         result: '') }
      @controller.stub :doorkeeper_token, token do
        request.env['HTTP_WORKER_UUID'] = 'this_is_another_worker_uuid'
        patch :batch_update, 
          params: { default: { format: 'json' },
                    jobs: Hash[_test_jobs.map{|j| [j.id, _test_job_json]}] }
      end
      _test_jobs.map(&:reload).map(&:result).uniq.must_equal ['']
    end

    it "updates jobs assigned to the calling worker" do
      _test_jobs.each{|j| j.update_columns(worker_uuid: "the_original_uuid",
                                         result: '') }
      @controller.stub :doorkeeper_token, token do
        request.env['HTTP_WORKER_UUID'] = 'the_original_uuid'
        patch :batch_update, 
          params: { default: { format: 'json' },
                    jobs: Hash[_test_jobs.map{|j| [j.id, _test_job_json]}] }
      end
      _test_jobs.map(&:reload).map(&:result).uniq.must_equal ['result']
    end
  end
end
