# This class implements all Github integration related methods.
# This is an adaptee class for RepositoryManager
class GithubRepositoryManager
  HISTORY_COMMITS_LIMIT = 30
  REPOSITORIES_PER_PAGE = 20

  # We want this for github_webhook_url
  include Rails.application.routes.url_helpers

  attr_reader :project, :project_wizard, :github_client, :errors

  def initialize(options)
    @project = options[:project] if options[:project]
    @project_wizard = options[:project_wizard] if options[:project_wizard]

    unless @project.is_a?(Project) || @project_wizard.is_a?(ProjectWizard)
      raise "GithubRepositoryProvider needs a project or a project wizard to be initialized"
    end

    @github_client =
      @project ? @project.user.github_client : @project_wizard.user.github_client
  end

  # Adds a new TestRun for the given commit in the current project
  def create_test_run!(params = {})
    test_run = TestRun.new(params)
    test_run = complete_test_run_params(test_run)
    return nil unless test_run

    test_run.save!

    GithubRepositoryManager::TestRunSetupJob.perform_later(test_run.id)

    test_run
  end

  # Creates TestJobs and assigns to chunks. Changes the status from SETUP
  # to QUEUED.
  #
  # Example yml file:
  # each:
  #   pattern: 'test/*/**_test.rb'
  #   command: 'bin/rake test %{file}'
  #   before: 'some_command'
  # javascript:
  #   command: 'bin/rake test_javascript'
  #   after: "some_cleanup_command"
  #
  # We assume that the JOBS_YML_PATH exists and has valid commands.
  # Sets setup_error if JOBS_YML_PATH is invalid?
  # @raises "JOBS_YML_PATH not found" if JOBS_YML_PATH doesn't exist?
  def setup_test_run(test_run)
    yml_contents = jobs_yml(test_run.commit_sha)
    raise "#{ProjectFile::JOBS_YML_PATH} not found" unless yml_contents
    testributor_yml = ProjectFile.new(path: ProjectFile::JOBS_YML_PATH,
                                      contents: yml_contents)

    # If testributor.yml comes from the repo it might be invalid
    if testributor_yml.invalid?
      test_run.status = TestStatus::ERROR
      # TODO: Show this in the view
      test_run.setup_error = "#{ProjectFile::JOBS_YML_PATH} file is invalid: "
      test_run.setup_error += testributor_yml.errors.full_messages.to_sentence
      test_run.save!

      return
    end

    jobs_description = YAML.load(yml_contents)

    if each_description = jobs_description.delete("each")
      pattern = each_description["pattern"]
      command = each_description["command"]
      before = each_description["before"].to_s
      after = each_description["after"].to_s

      file_names = project_file_names(test_run.commit_sha)
      file_names.select{|f| f.match(pattern)}.each do |f|
        test_run.test_jobs.build(
          job_name: f,
          command: command.gsub(/%{file}/, f),
          before: before,
          after: after
        )
      end
    end

    jobs_description.each do |job_name, description|
      command = description["command"]
      before = description["before"].to_s
      after = description["after"].to_s
      test_run.test_jobs.build(
        job_name: job_name,
        command: command,
        before: before,
        after: after
      )
    end
    Katanomeas.new(test_run).assign_chunk_indexes_to_test_jobs
    test_run.status = TestStatus::QUEUED

    test_run.save!

    Broadcaster.publish(test_run.redis_live_update_resource_key,
      { test_job: {}, test_run: test_run.reload.serialized_run })
  end

  # Returns the content of ProjectFile::JOBS_YML_PATH file.
  # The file can either be defined in Project's files
  # project_files association) or it can be checked in the
  # git repository. If defined both ways the repo version wins to let the users
  # use a customized file in specific branches (e.g. if they don't want to run
  # all tests on some feature branch they can commit this file to override the
  # global project configuration).
  def jobs_yml(commit_sha)
    file = nil

    if github_client.present?
      repo = project.repository_id
      file =
        begin
          file = github_client.contents(repo, path: ProjectFile::JOBS_YML_PATH,
                                        ref: commit_sha)

          Base64.decode64(file.content)
        rescue Octokit::NotFound
          nil
        end
    end

    if file.blank?
      file = project.project_files.where(path: ProjectFile::JOBS_YML_PATH).
        first.try(:contents)
    end

    file
  end

  # When github client is not set, this method returns false.
  # We should prompt the user to connect to github.
  def fetch_repos(page=0)
    page = page.to_i
    return false unless github_client.present?

    #https://developer.github.com/v3/repos/#list-user-repositories
    repos = github_client.repos(nil,
      { type: "owner", per_page: REPOSITORIES_PER_PAGE }.
        merge(page > 0 ? { page: page } : {})
    ).map { |repo| { id: repo.id, fork: repo.fork?, name: repo.full_name } }

    { repos: repos, last_response: github_client.last_response }
  end

  def fetch_branches
    return false if repository_id.blank? || github_client.blank?

    github_client.branches(repository_id).map do |b|
      TrackedBranch.new(branch_name: b.name)
    end
  end

  def fetch_branch_names
    return false if repository_id.blank? || github_client.blank?

    github_client.branches(repository_id).map(&:name)
  end

  def repository_data
    return @repository_data if @repository_data

    return false if repository_id.blank? || github_client.blank?

    repo_data = github_client.repo(repository_id)

    @repository_data = OpenStruct.new({
      repository_id: repo_data.id,
      repository_name: repo_data.name,
      repository_owner: repo_data.owner.login,
    })
  end

  def cleanup_for_removal
    return false unless project

    github_client.remove_hook(project.repository_id, project.webhook_id)
  end

  # Creates webhooks on GitHub
  def post_add_repository_setup
    begin
      hook = github_client.create_hook(repository_id, 'web',
        {
          secret: ENV['GITHUB_WEBHOOK_SECRET'],
          url: webhook_url, content_type: 'json'
        }, events: %w(push delete))
    rescue Octokit::UnprocessableEntity => e
      if e.message =~ /hook already exists/i
        hooks = github_client.hooks(repository_id)
        hook = hooks.select do |h|
          h.config.url == webhook_url && h.events == %w(push delete)
        end.first
      else
        raise e
      end
    end
  end

  private

  def repository_id
    project.try(:repository_id) || project_wizard.try(:repository_id)
  end

  def webhook_url
    ENV['GITHUB_WEBHOOK_URL'] || github_webhook_url(host: "www.testributor.com")
  end

  # Fetches the requested branch HEAD with the last 30 commits in history
  # If sha is set, it will be used instead of the branch name.
  def sha_history(sha_or_branch_name)
    github_client.commits(project.repository_id, sha_or_branch_name).
      first(HISTORY_COMMITS_LIMIT)
  end

  # Since we always need the sha_history, we always make a call to GitHub
  # and complete any missing params.
  def complete_test_run_params(test_run)
    test_run.project = project

    # At least commit_sha or branch must be defines to setup a new test run
    begin
      history =
        sha_history(test_run.commit_sha || test_run.tracked_branch.branch_name)
    rescue Octokit::NotFound
      @errors ||= []
      @errors <<
        if test_run.commit_sha
          ["Commit doesn't exist anymore on GitHub"]
        else
          ["Branch doesn't exist anymore on GitHub"]
        end

      return nil
    end

    latest_commit = history.first

    # Some of the params might already be there but since we have them fresh
    # we reassign them (we could reverse merge but that should produce the same
    # result).
    test_run.assign_attributes({
      commit_sha: latest_commit.sha,
      commit_message: latest_commit.commit.message,
      commit_timestamp: latest_commit.commit.committer.date,
      commit_url: latest_commit.html_url,
      commit_author_name: latest_commit.commit.author.name,
      commit_author_email: latest_commit.commit.author.email,
      commit_author_username: latest_commit.author.login,
      commit_committer_name: latest_commit.commit.committer.name,
      commit_committer_email: latest_commit.commit.committer.email,
      commit_committer_username: latest_commit.committer.login,
      sha_history: history.map(&:sha)
    })

    test_run
  end

  # This method returns all filenames for this repo and ref from github.
  # TODO: Github limit is something like 1000 files per request.
  # Refactor this method so that it always returns all filenames no matter
  # how many (or find some better solution).
  def project_file_names(commit_sha)
    repo = project.repository_id
    github_client.tree(repo, commit_sha, recursive: true)[:tree].map(&:path)
  end
end
