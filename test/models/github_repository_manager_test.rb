require 'test_helper'

class GithubRepositoryManagerTest < ActiveSupport::TestCase
  describe "#jobs_yml" do
    let(:_test_run) { FactoryGirl.create(:testributor_run) }
    let(:client) { Octokit::Client.new(access_token: "some_token") }
    let(:file) do
      file = mock
      file.stubs(:content).returns(Base64.encode64("repo version"))

      file
    end

    subject { GithubRepositoryManager.new(_test_run.project) }

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
          with(subject.project.repository_id,
               {path: ProjectFile::JOBS_YML_PATH, ref: _test_run.commit_sha}).
          returns(file)
      end

      it "returns the repo version" do
        subject.jobs_yml(_test_run.commit_sha).must_equal 'repo version'
      end
    end

    describe "when file only exists in the repo" do
      before do
        # Stub repo version
        client.stubs(:contents).
          with(subject.project.repository_id,
               {path: ProjectFile::JOBS_YML_PATH, ref: _test_run.commit_sha}).
          returns(file)
      end

      it "returns the repo version" do
        subject.jobs_yml(_test_run.commit_sha).must_equal 'repo version'
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
          with(subject.project.repository_id,
               {path: ProjectFile::JOBS_YML_PATH, ref: _test_run.commit_sha}).
          raises(Octokit::NotFound)
      end

      it "returns the project_files version" do
        subject.jobs_yml(_test_run.commit_sha).must_equal contents
      end
    end

    describe "when file does not exist" do
      before do
        # Stub repo version
        client.stubs(:contents).
          with(subject.project.repository_id,
               {path: ProjectFile::JOBS_YML_PATH, ref: _test_run.commit_sha}).
          raises(Octokit::NotFound)
      end

      it "returns nil" do
        subject.jobs_yml(_test_run.commit_sha).must_be :nil?
      end
    end
  end

  describe "#setup_test_run" do
    let(:_test_run) { FactoryGirl.create(:testributor_run) }
    subject { GithubRepositoryManager.new(_test_run.project) }

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
        subject.setup_test_run(_test_run)
        _test_run.reload.setup_error.
          must_equal "testributor.yml file is invalid: Contents syntax error"
        _test_run.status.code.must_equal TestStatus::ERROR
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
          subject.setup_test_run(_test_run)
          _test_run.reload.setup_error.
            must_equal "testributor.yml file is invalid: Contents 'each:' key without 'pattern:' key provided"
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
          subject.setup_test_run(_test_run)
          _test_run.reload.setup_error.
            must_equal "testributor.yml file is invalid: Contents 'each:' key without 'command:' key provided"
        end
      end

      it "creates jobs for all matching files replacing %{file}" do
        subject.setup_test_run(_test_run)
        _test_run.test_jobs.map(&:command).
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
        subject.setup_test_run(_test_run)
        _test_run.test_jobs.map(&:command).
          must_equal ['bin/rake test_javascript', 'bin/rake test_selenium']
        _test_run.test_jobs.map(&:before).must_equal ['some before command', '']
        _test_run.test_jobs.map(&:after).must_equal ['some after command', '']
      end
    end
  end
end
