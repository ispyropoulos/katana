# This class implements all BitBucket integration related methods.
# This is an adaptee class for RepositoryManager
class BitbucketRepositoryManager
  HISTORY_COMMITS_LIMIT = 30
  REPOSITORIES_PER_PAGE = 10
  PROJECT_FILES_DIRECTORY_DEPTH =
    ENV["BITBUCKET_PROJECT_FILES_DIRECTORY_DEPTH"] || 3

  # We want this for bitbucket_webhook_url
  include Rails.application.routes.url_helpers

  attr_reader :project, :bitbucket_client, :errors

  def initialize(project)
    @project = project

    unless @project.is_a?(Project)
      raise "BitbucketRepositoryProvider needs a Project to be initialized"
    end

    @bitbucket_client = @project.user.bitbucket_client
  end

  # Adds a new TestRun for the given commit in the current project
  def create_test_run!(params = {})
    test_run = TestRun.new(params)
    test_run = complete_test_run_params(test_run)
    return nil unless test_run

    test_run.save!
    schedule_test_run_setup(test_run)

    test_run
  end

  def schedule_test_run_setup(test_run)
    BitbucketRepositoryManager::TestRunSetupJob.perform_later(test_run.id)
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

    jobs_description = SafeYAML.load(yml_contents)

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
    file =
      begin
        file = bitbucket_client.repos.sources.get(repository_owner, repository_slug,
          commit_sha, ProjectFile::JOBS_YML_PATH)
        Base64.decode64(file.content)
      rescue BitBucket::Error::NotFound
        nil
      end

    if file.blank?
      file = project.project_files.where(path: ProjectFile::JOBS_YML_PATH).
        first.try(:contents)
    end

    file
  end

  # Return a Hash with all the Bitbucket repositories that the current user
  # a) owns (implicit admin), or
  # b) has administrative rights in Teams that owns them (implicit admin), or
  # c) has administrative rights for (explicit admin). This is the case when the
  #    user is an admin only on this repository and not the team that owns it.
  def fetch_repos(page=0)
    # https://confluence.atlassian.com/display/bitbucket/user+endpoint#userEndpoint-GETalistofrepositoriesvisibletoanaccount
    repos = bitbucket_client.user_api.repositories
    repository_slugs_by_owner =
      repos.group_by(&:owner).map{|k,v| [k, v.map(&:slug)]}.to_h

    # https://confluence.atlassian.com/display/bitbucket/user+endpoint#userEndpoint-GETalistofuserprivileges
    administered_teams = bitbucket_client.user_api.privileges.teams.
      reject { |_,v| v != 'admin' }.keys

    # All the projects that match both the owner and the slug (this combination
    # is unique on Bitbucket)
    already_imported_projects = Project.bitbucket.
      where(repository_slug: repos.map(&:slug)).select do |p|
      p.repository_slug.in?(repository_slugs_by_owner[p.repository_owner].to_a)
    end

    repos = repos.map do |repo|
      already_imported_project = already_imported_projects.detect do |p|
        p.repository_slug == repo.slug && p.repository_owner == repo.owner
      end

      user_is_explicit_admin_on_repo = ->{
        username.in?(bitbucket_client.privileges.
          list_on_repo(repo.owner, repo.slug, filter: 'admin').
          map{ |p| p.user.username })
      }

      cannot_import_message =
        if already_imported_project.present? &&
          already_imported_project.members.include?(project.user)
          "You already participate in a project based on this repository"
        elsif (owner = already_imported_project.try(:user).try(:email))
          "Please ask user #{owner} to invite you"
        # Admin check
        elsif repo.owner != username && !repo.owner.in?(administered_teams) &&
          begin
            !user_is_explicit_admin_on_repo.call
          rescue BitBucket::Error::Forbidden
            next
          end
          "You need administrative rights to select this repository"
        end

      {
        slug: repo.slug,
        description: repo.description,
        is_fork: repo.is_fork?,
        full_name: "#{repo.owner}/#{repo.name}",
        owner: repo.owner,
        name: repo.name,
        cannot_import_message: cannot_import_message,
        is_private: repo.is_private
      }
    end

    { repos: repos.compact }
  end

  def fetch_branches
    branches = bitbucket_client.repos.branches(repository_owner, repository_slug)
    already_tracked_branch_names = project.tracked_branches.map(&:branch_name)

    branches = branches.map do |name, _|
      cannot_import_message =
        if name.in?(already_tracked_branch_names)
          "You are already tracking this branch"
        end

      {
        name: name,
        cannot_import_message: cannot_import_message
      }
    end

    { branches: branches }
  end

  # Removes a webhook from Bitbucket
  def cleanup_for_removal
    bitbucket_client.repos.webhooks.delete(repository_owner, repository_slug,
      project.webhook_id) if project.webhook_id
  end

  # Creates a webhook on Bitbucket
  def post_add_repository_setup
    webhook_id =
      bitbucket_client.repos.webhooks.create(repository_owner, repository_slug,
        description: "Testributor Webhook#{" (local)" if Rails.env.development?}",
        url: webhook_url,
        active: true,
        events: ['repo:push']
      ).uuid

    # Thw :webhook_id contains the raw value as returned by the Bitbucket API,
    # e.g. {4e30dc03-4b53-441e-921e-dd27a4b3ff25}
    #
    # Therefore, it is recommended to use it only for storage purposes. The
    # correct way to retrieve a consumption-ready UUID would be to call the
    # Project#webhook_id method.
    { webhook_id: webhook_id }
  end

  def set_deploy_key(key, options={})
    bitbucket_client.repos.keys.create(repository_owner, repository_slug,
      label: options[:friendly_name],
      key: key)
  end

  def remove_deploy_key(key_id)
    bitbucket_client.repos.keys.delete(repository_owner, repository_slug, key_id)
  end

  def publish_status_notification(test_run)
    # TODO We need to implement this and submit a PR to the BitBucketAPI gem
  end

  private

  def repository_slug
    project.try(:repository_slug)
  end

  def webhook_url
    # Bitbucket will not accept URLs with "localhost" as the host, so we override
    # the default host in order to have a working fallback for development.
    ENV['BITBUCKET_WEBHOOK_URL'] || bitbucket_webhook_url(host: "www.testributor.com")
  end

  # Fetches the requested branch HEAD with the last 30 commits in history
  # If sha is set, it will be used instead of the branch name.
  def sha_history(sha_or_branch_name)
    bitbucket_client.repos.commits.
      list(repository_owner, repository_slug, nil, include: sha_or_branch_name)['values'].
      first(HISTORY_COMMITS_LIMIT)
  end

  # Since we always need the sha_history, we always make a call to GitHub
  # and complete any missing params.
  def complete_test_run_params(test_run)
    test_run.project = project

    # At least commit_sha or branch must be defined to setup a new test run
    begin
      history =
        sha_history(test_run.commit_sha || test_run.tracked_branch.branch_name)
    rescue BitBucket::Error::NotFound
      @errors ||= []
      @errors <<
        if test_run.commit_sha
          ["Commit doesn't exist anymore on Bitbucket"]
        else
          ["Branch doesn't exist anymore on Bitbucket"]
        end

      return nil
    end

    latest_commit = history.first

    # Some of the params might already be there but since we have them fresh
    # we reassign them (we could reverse merge but that should produce the same
    # result).
    author = latest_commit.author
    user = author.user
    test_run.assign_attributes({
      commit_sha: latest_commit['hash'],
      commit_message: latest_commit.message,
      commit_timestamp: latest_commit['date'],
      commit_url: latest_commit['links'].html.href,
      commit_author_name: user ? user.display_name : author.raw,
      commit_author_email: latest_commit.author.raw,
      commit_author_username: user ? user.username : author.raw,
      commit_committer_name: user ? user.display_name : author.raw,
      commit_committer_email: latest_commit.author.raw,
      commit_committer_username: user ? user.username : author.raw,
      commit_committer_photo_url: photo_url(latest_commit),
      sha_history: history.map{|c|c['hash']}
    })

    test_run
  end

  # This method returns all filenames and paths for this repo.
  #
  # As BitBucket API does not currently offer a way to retrieve the filenames in
  # single call, recursively, we do implement the recursion ourselves. This means
  # that we "hit" the BitBucket multiple times and in a very short time window.
  # For this reason, we deliberately limit the directory depth for the recursive
  # loop, as a sanity measure for avoiding an excessive number of requests.
  #
  # Here are some actual benchmarks, starting from the root of typical Rails repo
  #
  # level = 0 ->  9.43 sec
  # level = 1 -> 33.44 sec
  # level = 2 -> 60.81 sec
  # level = 3 -> 78.52 sec
  #
  def project_file_names(commit_sha, path='/', level=PROJECT_FILES_DIRECTORY_DEPTH)
    sources = bitbucket_client.repos.sources.list(repository_owner, repository_slug, commit_sha, path)
    paths = sources['files'].map { |file| file['path'] }
    if level > -1
      sources['directories'].each do |directory|
        paths += project_file_names(commit_sha, "#{sources['path']}/#{directory}/", level - 1)
      end
    end

    paths
  end

  def username
    @username ||= bitbucket_client.user_api.profile.user.username
  end

  def repository_owner
    project.try(:repository_owner)
  end

  def user
    project.user
  end

  private

  def photo_url(commit)
    commit["author"].try(:[], "user").try(:[], "links").try(:[],"avatar").try(:[], "href")
  end
end
