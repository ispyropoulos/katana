class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable, :omniauthable, omniauth_providers: %w(github)

  # TODO: remove this hardcoded key and change all the VCR cassettes
  if Rails.env.test?
    attr_encrypted_options.merge!(
      key: 'cruns-iaj-taV-Eyg-uN-rOwz-aG',
      mode: :per_attribute_iv_and_salt)
  else
    attr_encrypted_options.merge!(
      key: ENV['ENCRYPTED_TOKEN_SECRET'], mode: :per_attribute_iv_and_salt)
  end

  attr_encryptor :github_access_token
  attr_encryptor :bitbucket_access_token, :bitbucket_access_token_secret, unless: Rails.env.test?

  has_many :user_invitations, dependent: :destroy
  has_many :projects # on which this user is an owner
  has_many :project_participations, dependent: :destroy
  has_many :participating_projects, through: :project_participations,
    class_name: "Project", source: :project
  has_many :tracked_branches, through: :participating_projects
  has_many :test_runs, through: :tracked_branches
  has_many :feedback_submissions

  GITHUB_REQUIRED_SCOPES = %w(user:email repo)

  def participation_for_project(project_id)
    project_participations.find_by!(project_id: project_id)
  end

  def can_create_new_project?
    projects_limit >= Project.where(user_id: id).count + 1
  end

  def github_client
    # The use of #to_s is intentional, as we never want to pass a nil value to
    # the :access_token option, because the Octokit client will raise an
    # Octokit::NotFound error instead of an Octokit::Unauthorized. The latter is
    # handled at a controller level.
    Octokit::Client.new(access_token: github_access_token.to_s)
  end

  def bitbucket_client
    BitBucket.new(oauth_token: bitbucket_access_token,
      oauth_secret: bitbucket_access_token_secret)
  end

  def self.from_omniauth(auth)
    return nil unless auth.info.email

    if user = User.find_by(email: auth.info.email)
      user.update(provider: auth.provider,
                  uid: auth.uid,
                  confirmed_at: user.confirmed_at || Date.current)

      user
    else
      where(provider: auth.provider, uid: auth.uid).first_or_create! do |auth_user|
        auth_user.provider = auth.provider
        auth_user.uid = auth.uid
        auth_user.email = auth.info.email
        auth_user.confirmed_at = Date.current
        auth_user.password = Devise.friendly_token[0,20]
      end
    end
  end
end
