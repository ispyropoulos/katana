# This is the base class that represents a repository.
# Subclass this and override its methods for custom behavior.
# E.g. Repositories::GitRepository
# A repository is always represented by the url and an authentication
# token that will be provided in order to grant access to the repository.
class Repository
  def initialize(url, access_token)
    @url = url
    @access_token = access_token
  end

  # List all branches in a repository
  def branches
    raise "Implement your own adapter for listing branches"
  end
end
