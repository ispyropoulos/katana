class WorkerGroup < ActiveRecord::Base
  belongs_to :oauth_application, class_name: 'Doorkeeper::Application'
  belongs_to :project

  attr_encryptor :ssh_key_private, key: ENV['ENCRYPTED_TOKEN_SECRET'],
    mode: :per_attribute_iv_and_salt, unless: Rails.env.test?

  validates :project, presence: true
  validates :friendly_name, presence: true
  validates :friendly_name, uniqueness: { scope: :project }

  before_validation :generate_ssh_keys, on: :create,
    if: ->{ ssh_key_private.blank? }
  before_create :set_ssh_key_in_repo, unless: ->{ Rails.env.test? }
  before_save :rename_ssh_key_in_repo,
    if: ->{ friendly_name_changed? && !Rails.env.test? }
  after_destroy :remove_ssh_key_from_repo,
    if: ->{ ssh_key_provider_reference_id_was }

  def reset_ssh_key!
    remove_ssh_key_from_repo
    generate_ssh_keys
    set_ssh_key_in_repo

    save!
  end

  private

  def set_ssh_key_in_repo
    deploy_key_id = repository_manager.set_deploy_key(ssh_key_public,
      { friendly_name: friendly_name, read_only: true })

    self.ssh_key_provider_reference_id = deploy_key.id
  end

  def generate_ssh_keys
    ssh_key = SSHKey.generate(bits: 4096, comment: project.user.email)
    self.ssh_key_private = ssh_key.private_key
    self.ssh_key_public = ssh_key.ssh_public_key
  end

  def remove_ssh_key_from_repo
    repository_manager.remove_deploy_key(ssh_key_provider_reference_id)
  end

  def rename_ssh_key_in_repo
    remove_ssh_key_from_repo
    set_ssh_key_in_repo
  end

  def repository_manager
    @repository_manager ||=
      RepositoryManager.new({ project: project })
  end
end
