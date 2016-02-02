require 'test_helper'

class TestRunTest < ActiveSupport::TestCase
  let(:_test_run) { FactoryGirl.create(:testributor_run, :passed) }

  describe "#cancel_test_jobs" do
    subject { FactoryGirl.create(:testributor_run, :passed) }
    before do
      subject.test_jobs.create!(command: "ls", status: TestStatus::QUEUED)
      subject.test_jobs.create!(command: "ls", status: TestStatus::QUEUED)
    end

    it "cancels the test_jobs when it is cancelled" do
      subject.status = TestStatus::CANCELLED
      subject.save!
      subject.test_jobs.reload.pluck(:status).uniq.must_equal [TestStatus::CANCELLED]
    end
  end

  describe "previous_run" do
    let(:project) { FactoryGirl.create(:project) }
    let(:branch_1) { FactoryGirl.create(:tracked_branch, project: project) }
    let(:branch_2) { FactoryGirl.create(:tracked_branch, project: project) }

    subject do
      FactoryGirl.create(:testributor_run, :passed, tracked_branch: branch_1,
        commit_sha: '3333', sha_history: ['3333', '2222', '1111', '0000'])
    end

    describe "when there are previous TestRuns that match the history" do
      let(:previous_run) do
        FactoryGirl.create(:testributor_run, :passed, tracked_branch: branch_2,
          commit_sha: '1111')
      end
      let(:older_commit_previous_run) do
        FactoryGirl.create(:testributor_run, :passed, tracked_branch: branch_1,
          commit_sha: '0000')
      end
      before do
        older_commit_previous_run
        previous_run
      end

      it "returns the first match" do
        subject.previous_run.must_equal previous_run
      end
    end

    describe "when there are not previous TestRuns that match the history" do
      it "returns nil" do
        subject.previous_run.must_equal nil
      end
    end
  end

  describe "most_relevant_run" do
    let(:branch) { FactoryGirl.create(:tracked_branch) }

    subject do
      FactoryGirl.create(:testributor_run, :passed, tracked_branch: branch,
        commit_sha: '3333', sha_history: ['3333', '2222', '1111', '0000'])
    end

    let(:most_recent_non_previous_run) do
      FactoryGirl.create(:testributor_run, :passed, tracked_branch: branch,
        commit_sha: 'nothing_to_do_with_the_history_sha')
    end

    before { most_recent_non_previous_run }

    describe "when there are previous TestRuns that match the history" do
      let(:previous_run) do
        FactoryGirl.create(:testributor_run, :passed, tracked_branch: branch,
          commit_sha: '1111')
      end

      before do
        Timecop.travel(1.month.ago) { previous_run }
      end

      it "returns the first match even when more recent exist" do
        subject.most_relevant_run.must_equal previous_run
      end
    end

    describe "when there are not previous TestRuns that match the history" do
      it "returns the most recent run" do
        subject.most_relevant_run.must_equal most_recent_non_previous_run
      end

      describe "when there are no TestRuns at all" do
        before { most_recent_non_previous_run.destroy }

        it 'returns nil' do
          subject.most_relevant_run.must_be :nil?
        end
      end
    end
  end

  describe "retry?" do
    subject { FactoryGirl.build(:testributor_run) }

    it "returns false when TestRun is queued" do
      subject.status = TestStatus::QUEUED
      subject.wont_be :retry?
    end

    it "returns false when TestRun is running" do
      subject.status = TestStatus::RUNNING
      subject.wont_be :retry?
    end

    it "returns false when TestRun is cancelled" do
      subject.status = TestStatus::CANCELLED
      subject.wont_be :retry?
    end

    it "returns true when TestRun is passed" do
      subject.status = TestStatus::PASSED
      subject.must_be :retry?
    end

    it "returns true when TestRun is failed" do
      subject.status = TestStatus::FAILED
      subject.must_be :retry?
    end

    it "returns true when TestRun is error" do
      subject.status = TestStatus::ERROR
      subject.must_be :retry?
    end
  end

  describe "#jobs_yml" do
    subject { FactoryGirl.create(:testributor_run) }
    let(:client) { Octokit::Client.new(access_token: "some_token") }
    let(:file) do
      file = mock
      file.stubs(:content).returns(Base64.encode64("repo version"))

      file
    end

    before do
      subject.stubs(:github_client).returns(client)
    end

    describe "when file exists both in project_files and repo" do
      before do
        # project_files version
        subject.project.project_files.create(
          path: ProjectFile::JOBS_YML_PATH, contents: "project_files version")

        # Stub repo version
        client.stubs(:contents).
          with(subject.tracked_branch.project.repository_id,
               {path: ProjectFile::JOBS_YML_PATH, ref: subject.commit_sha}).
          returns(file)
      end

      it "returns the repo version" do
        subject.jobs_yml.must_equal 'repo version'
      end
    end

    describe "when file only exists in the repo" do
      before do
        # Stub repo version
        client.stubs(:contents).
          with(subject.tracked_branch.project.repository_id,
               {path: ProjectFile::JOBS_YML_PATH, ref: subject.commit_sha}).
          returns(file)
      end

      it "returns the repo version" do
        subject.jobs_yml.must_equal 'repo version'
      end
    end

    describe "when file only exists in project_files" do
      let(:contents) do
        <<-YAML
          each:
            command: 'bin/rake test'
            pattern: 'test/models/*_test.rb'
        YAML
      end

      before do
        # project_files version
        subject.project.project_files.create(
          path: ProjectFile::JOBS_YML_PATH, contents: contents)

        client.stubs(:contents).
          with(subject.tracked_branch.project.repository_id,
               {path: ProjectFile::JOBS_YML_PATH, ref: subject.commit_sha}).
          raises(Octokit::NotFound)
      end

      it "returns the project_files version" do
        subject.jobs_yml.must_equal contents
      end
    end

    describe "when file does not exist" do
      before do
        # Stub repo version
        client.stubs(:contents).
          with(subject.tracked_branch.project.repository_id,
               {path: ProjectFile::JOBS_YML_PATH, ref: subject.commit_sha}).
          raises(Octokit::NotFound)
      end

      it "returns nil" do
        subject.jobs_yml.must_be :nil?
      end
    end
  end

  describe "build_test_jobs" do
    subject { FactoryGirl.create(:testributor_run) }

    before do
      subject.stubs(:project_file_names).returns(
        ['test/models/user_test.rb', 'test/features/funny_feature_test.rb'])
      subject.stubs(:jobs_yml).returns(yml)
    end

    describe 'when yml has syntax error' do
      let(:yml) do
        <<-YML
          invalid_ymls_suck
          each:
            pattern: '.*funny.*'
            command: "bin/rake test %{file}"
        YML
      end

      it "adds errors" do
        subject.build_test_jobs
        subject.errors.values.join(", ").must_equal "syntax error"
      end
    end

    describe 'when "each" key exists' do
      let(:yml) do
        <<-YML
          each:
            pattern: '.*funny.*'
            command: "bin/rake test %{file}"
        YML
      end

      describe 'but no "pattern" exists' do
        let(:yml) do
          <<-YML
            each:
              command: 'some command'
          YML
        end

        it "adds errors" do
          subject.build_test_jobs
          subject.errors.values.join(", ").
            must_equal "'each:' key without 'pattern:' key provided"
        end
      end

      describe 'but no "command" exists' do
        let(:yml) do
          <<-YML
            each:
              pattern: '.*'
          YML
        end

        it "adds errors" do
          subject.build_test_jobs
          subject.errors.values.join(", ").
            must_equal "'each:' key without 'command:' key provided"
        end
      end

      it "creates jobs for all matching files replacing %{file}" do
        subject.build_test_jobs.must_equal true
        subject.test_jobs.map(&:command).
          must_equal ["bin/rake test test/features/funny_feature_test.rb"]
      end
    end

    describe 'when "raw" jobs exist' do
      let(:yml) do
        <<-YML
          each:
            pattern: 'no_match'
            command: "bin/rake test %{file}"
          javascript:
            command: "bin/rake test_javascript"
            before: "some before command"
            after: "some after command"
          selenium:
            command: "bin/rake test_selenium"
        YML
      end

      it "builds all specified jobs" do
        subject.build_test_jobs
        subject.test_jobs.map(&:command).
          must_equal ['bin/rake test_javascript', 'bin/rake test_selenium']
        subject.test_jobs.map(&:before).must_equal ['some before command', '']
        subject.test_jobs.map(&:after).must_equal ['some after command', '']
      end
    end
  end

  describe "#add_chunks_to_redis_queue (private)" do
    subject { FactoryGirl.build(:testributor_run) }
    before do
      10.times {
        subject.test_jobs.build(command: "ls", status: TestStatus::QUEUED)
      }
      Katanomeas.new(subject).assign_chunk_indexes_to_test_jobs
    end

    it "adds the chunk in Redis queue" do
      subject.save!
      Katana::Application.redis.lrange(
        subject.project.test_runs_chunks_redis_key, 0, -1
      ).must_equal((0..9).to_a.reverse.map{|i| "#{subject.id}_#{i}"})
    end
  end
end
