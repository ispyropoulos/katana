# This is an Adapter class that delegates the various repository specific
# methods to the provider specific Adaptees.
class RepositoryManager
  attr_reader :manager # the adaptee object

  delegate :create_test_run!, to: :manager

  def initialize(project)
    case project.repository_provider
    when "github"
      @manager = GithubRepositoryManager.new(project)
    else
      raise "Unknown repository provider"
    end
  end
end
