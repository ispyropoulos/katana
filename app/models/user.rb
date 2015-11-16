class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable and :omniauthable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable, :omniauthable, omniauth_providers: %w(github)

  if Rails.env.test?
    attr_encrypted_options.merge!(
      key: 'cruns-iaj-taV-Eyg-uN-rOwz-aG',
      mode: :per_attribute_iv_and_salt)
  else
    attr_encrypted_options.merge!(
      key: ENV['ENCRYPTED_TOKEN_SECRET'], mode: :per_attribute_iv_and_salt)
  end
  attr_encryptor :github_access_token

  belongs_to :invited_by, class_name: "Project"
  has_many :projects # on which this user is an owner
  has_and_belongs_to_many :participating_projects, class_name: "Project"
  has_many :tracked_branches, through: :participating_projects
  has_many :test_runs, through: :tracked_branches
  has_one :project_wizard


  GITHUB_REQUIRED_SCOPES = %w(user:email repo)

  def can_create_new_project?
    projects_limit >= Project.where(user_id: id).count + 1
  end

  def github_client
    if github_access_token.present?
      client = Octokit::Client.new(access_token: github_access_token)

      (client.scopes & GITHUB_REQUIRED_SCOPES).size == 2 ? client : nil
    end
  rescue Octokit::Unauthorized
    return
  end

  def self.from_omniauth(auth)
    if user = User.find_by(email: auth.email)
      user.update(provider: auth.provider,
                  uid: auth.uid,
                  confirmed_at: user.confirmed_at || Date.current)

      user
    else
      where(provider: auth.provider, uid: auth.uid).first_or_create! do |auth_user|
        auth_user.provider = auth.provider
        auth_user.uid = auth.uid
        auth_user.email = auth.email
        auth_user.confirmed_at = Date.current
        auth_user.password = Devise.friendly_token[0,20]
      end
    end
  end
end
