require 'test_helper'

class TestJobTest < ActiveSupport::TestCase
  subject { TestJob.new }

  describe '#sent_at_seconds_since_epoch=' do
    describe 'when no seconds are passed' do
      it '#sent_at should return nil' do
        subject.sent_at.must_be_nil
      end
    end

    describe 'when some seconds are passed' do
      let(:time_now) { Time.current }
      let(:epoch_seconds) { time_now.to_i }

      before do
        subject.sent_at_seconds_since_epoch = epoch_seconds
      end

      it '#sent_at should return nil' do
        subject.sent_at.to_s.must_equal time_now.to_s
      end
    end
  end

  describe "#set_avg_worker_command_run_seconds" do
    let(:_test_run) do
      FactoryGirl.create(:testributor_run, commit_sha: '3333',
                         sha_history: ['3333', '2222', '1111', '0000'])
    end

    let(:previous_run) do
      FactoryGirl.create(:testributor_run, :passed, commit_sha: '1111',
                         tracked_branch: _test_run.tracked_branch)
    end

    let(:most_relevant_job) do
      FactoryGirl.create(:testributor_job, test_run: previous_run,
        command: "and conquer", worker_command_run_seconds: 400)
    end

    subject do
      FactoryGirl.create(:testributor_job, test_run: _test_run,
                         command: "and conquer", status: TestStatus::PASSED)
    end

    it "sets average to worker_command_run_seconds when there is no relevant job" do
      subject.worker_command_run_seconds = 123
      subject.valid?
      subject.avg_worker_command_run_seconds.must_equal 123
    end

    it "sets average to the weighted avg when there is a relevant job" do
      most_relevant_job
      previous_run.update_column(:status, TestStatus::PASSED)

      subject.worker_command_run_seconds = 123
      subject.valid?
      subject.avg_worker_command_run_seconds.to_d.must_equal(
        (400 * TestJob::NUMBER_OF_SIGNIFICANT_RUNS + 123) /
          (TestJob::NUMBER_OF_SIGNIFICANT_RUNS + 1).to_d)
    end

    it "does not set average on new records" do
      subject = FactoryGirl.build(:testributor_job, test_run: _test_run,
                         command: "and conquer", status: TestStatus::PASSED)
      most_relevant_job
      previous_run.update_column(:status, TestStatus::PASSED)

      subject.valid?
      subject.avg_worker_command_run_seconds.must_be :nil?
    end
  end

  describe "#set_old_avg_worker_command_run_seconds" do
    let(:_test_run) do
      FactoryGirl.create(:testributor_run, commit_sha: '3333',
                         sha_history: ['3333', '2222', '1111', '0000'])
    end

    let(:previous_run) do
      FactoryGirl.create(:testributor_run, :passed, commit_sha: '1111',
                         tracked_branch: _test_run.tracked_branch)
    end

    let(:most_relevant_job) do
      FactoryGirl.create(:testributor_job, test_run: previous_run,
        command: "and conquer", worker_command_run_seconds: 400)
    end

    subject do
      FactoryGirl.create(:testributor_job, test_run: _test_run,
                         command: "and conquer", status: TestStatus::PASSED)
    end

    it "does not run on persisted objects" do
      subject.expects(:set_old_avg_worker_command_run_seconds).never
      subject.valid?
    end

    it "sets old average to the avg of the most relevant job it exists" do
      most_relevant_job
      previous_run.update_column(:status, TestStatus::PASSED)

      subject.valid?
      subject.old_avg_worker_command_run_seconds.must_equal(
        most_relevant_job.avg_worker_command_run_seconds)
    end

    it "does not change the old avg when already set" do
      subject = FactoryGirl.build(:testributor_job,
        test_run: _test_run, command: "and conquer",
        status: TestStatus::PASSED, old_avg_worker_command_run_seconds: 30)

      most_relevant_job
      previous_run.update_column(:status, TestStatus::PASSED)

      subject.valid?
      subject.old_avg_worker_command_run_seconds.must_equal 30
    end
  end

  describe "#most_relevant_job" do
    let(:_test_run) do
      FactoryGirl.create(:testributor_run, commit_sha: '3333',
                         sha_history: ['3333', '2222', '1111', '0000'])
    end

    let(:previous_run) do
      FactoryGirl.create(:testributor_run, :passed, commit_sha: '1111',
                         tracked_branch: _test_run.tracked_branch)
    end

    subject do
      FactoryGirl.create(:testributor_job, test_run: _test_run,
                         command: "and conquer")
    end

    let(:most_relevant_job) do
      FactoryGirl.create(:testributor_job, test_run: previous_run,
                         command: "and conquer", status: TestStatus::PASSED)
    end

    before do
      most_relevant_job
      previous_run.update_column(:status, TestStatus::PASSED)
    end

    it "returns the most relevant job" do
      subject.most_relevant_job.must_equal most_relevant_job
    end

    describe "when the test_run most_relevant_run is nil" do
      before { previous_run.destroy }

      it "returns nil" do
        subject.most_relevant_job.must_be :nil?
      end
    end
  end

  describe '#total_running_time' do
    describe 'when times not reported yet' do
      it 'should return nil' do
        subject.total_running_time.must_be_nil
      end
    end

    describe 'when times reported' do
      before do
        time_now = Time.current
        subject.sent_at = time_now - 5.minutes
        subject.reported_at = time_now - 2.minutes
        subject.worker_in_queue_seconds = 60
      end

      it 'should return the duration between the reported and started points' do
        # 2 minutes ago - 5 minutes ago - 1 minute
        subject.total_running_time.must_equal 120 # seconds
      end
    end
  end

  describe '#complete_at' do
    before { subject.valid? }

    describe 'when times not reported yet' do
      it 'should return nil' do
        subject.completed_at.must_be_nil
      end
    end

    describe 'when times reported' do
      let(:five_minutes_ago) { 5.minutes.ago }
      before do
        subject.sent_at = five_minutes_ago
        subject.worker_in_queue_seconds = 60
        subject.worker_command_run_seconds = 2.3
        subject.valid?
      end

      it 'should return the duration between the reported and started points' do
        # 5 minutes ago + 1 minute + 2 minutes (rounded)
        subject.completed_at.must_equal (five_minutes_ago + 62.seconds)
      end
    end
  end

  describe '#update_test_run_status' do
    let(:_test_run) { FactoryGirl.create(:testributor_run) }


    describe 'when all testjobs have the same status' do
      it 'updates the test run status based on the test_jobs' do
        FactoryGirl.create_list(:testributor_job, 2, test_run: _test_run)
        [TestStatus::QUEUED, TestStatus::PASSED,
         TestStatus::FAILED, TestStatus::ERROR, TestStatus::CANCELLED].each do |status|
          _test_run.test_jobs.update_all(:status => status)

          _test_run.test_jobs.count.must_equal 2
          _test_run.update_status!
          _test_run.reload.status.code.must_equal status
        end
      end
    end

    describe 'when there are 2 different statuses' do
      it 'updates to running if queued in statuses' do
        FactoryGirl.create(:testributor_job, test_run: _test_run, status: TestStatus::QUEUED)
        FactoryGirl.create(:testributor_job, test_run: _test_run, status: TestStatus::ERROR)
        FactoryGirl.create(:testributor_job, test_run: _test_run, status: TestStatus::ERROR)

        _test_run.update_status!
        _test_run.reload.status.code.must_equal TestStatus::RUNNING
      end

      it 'updates to error if error in statuses and there is no queued' do
        FactoryGirl.create(:testributor_job, test_run: _test_run, status: TestStatus::FAILED)
        FactoryGirl.create(:testributor_job, test_run: _test_run, status: TestStatus::FAILED)
        FactoryGirl.create(:testributor_job, test_run: _test_run, status: TestStatus::ERROR)

        _test_run.update_status!
        _test_run.reload.status.code.must_equal TestStatus::ERROR
      end

      it 'updates to fail if fail in statuses and there is no queued or error in statuses' do
        FactoryGirl.create(:testributor_job, test_run: _test_run, status: TestStatus::PASSED)
        FactoryGirl.create(:testributor_job, test_run: _test_run, status: TestStatus::PASSED)
        FactoryGirl.create(:testributor_job, test_run: _test_run, status: TestStatus::FAILED)

        _test_run.update_status!
        _test_run.reload.status.code.must_equal TestStatus::FAILED
      end
    end

    describe 'when there are 3 different statuses' do
      it 'updates to running if queued in statuses' do
        FactoryGirl.create(:testributor_job, test_run: _test_run, status: TestStatus::QUEUED)
        FactoryGirl.create(:testributor_job, test_run: _test_run, status: TestStatus::PASSED)
        FactoryGirl.create(:testributor_job, test_run: _test_run, status: TestStatus::FAILED)

        _test_run.update_status!
        _test_run.reload.status.code.must_equal TestStatus::RUNNING
      end

      it 'updates to error if error in statuses and there is no queued' do
        FactoryGirl.create(:testributor_job, test_run: _test_run, status: TestStatus::PASSED)
        FactoryGirl.create(:testributor_job, test_run: _test_run, status: TestStatus::FAILED)
        FactoryGirl.create(:testributor_job, test_run: _test_run, status: TestStatus::ERROR)

        _test_run.update_status!
        _test_run.reload.status.code.must_equal TestStatus::ERROR
      end
    end

    describe 'when there are 4 different statuses' do
      # Normally there should be no cancelled status in test job
      # unless they are all cancelled but in any case eg: race condition
      it 'updates to cancelled if cancelled in statuses' do
        [TestStatus::QUEUED, TestStatus::FAILED,
         TestStatus::ERROR, TestStatus::CANCELLED].each do |status|

          FactoryGirl.create(:testributor_job, test_run: _test_run, status: status)
        end

        _test_run.test_jobs.count.must_equal 4
        _test_run.update_status!
        _test_run.reload.status.code.must_equal 5
      end

      it 'updates to running' do
        [TestStatus::QUEUED, TestStatus::FAILED,
         TestStatus::ERROR, TestStatus::PASSED].each do |status|

          FactoryGirl.create(:testributor_job, test_run: _test_run, status: status)
        end

        _test_run.test_jobs.count.must_equal 4
        _test_run.update_status!
        _test_run.reload.status.code.must_equal 1
      end
    end
  end
end
