require 'test_helper'

class TestRunTest < ActiveSupport::TestCase
  let(:_test_run) { FactoryGirl.create(:testributor_run) }

  describe "#cancel_test_jobs" do
    subject { FactoryGirl.create(:testributor_run) }
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
end
