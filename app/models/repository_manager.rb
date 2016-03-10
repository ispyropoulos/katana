# This is an Adapter class that delegates the various repository specific
# methods to the provider specific Adaptees.
class RepositoryManager
  attr_reader :manager # the adaptee object

  delegate :create_test_run!, :fetch_repos, :fetch_branches, :fetch_branch_names,
    :repository_data, :cleanup_for_removal, :post_add_repository_setup,
    :set_deploy_key, :remove_deploy_key, :publish_status_notification,
    to: :manager

  # Can be initialized either with a project of a project_wizard
  # @option options [Hash]
  #
  # E.g. { project: <Project> } or { project_wizard: <ProjectWizard> }
  def initialize(options)
    repository_provider =
      (options[:project] || options[:project_wizard]).repository_provider

    case repository_provider
    when "github"
      @manager = GithubRepositoryManager.new(options)
    else
      raise "Unknown repository provider"
    end
  end
end
