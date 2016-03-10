class ProjectSerializer < ActiveModel::Serializer
  attributes :repository_ssh_url

  has_many :files
  has_one :docker_image

  # TODO We should probably discover and cache those urls via the provider's API
  # instead of constructing them ourselves, as they may change at some point.
  def repository_ssh_url
    case object.repository_provider
    when 'github'
      "git@github.com:#{object.repository_owner}/#{object.repository_name}.git"
    else
      nil # don't know how to construct the SSH url
    end
  end

  def files
    object.project_files
  end

  def docker_image
    { name: object.docker_image.standardized_name, version: object.docker_image.version }
  end
end
