class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable

  attr_encrypted_options.merge!(key: ENV['ENCRYPTED_TOKEN_SECRET'],
    mode: :per_attribute_iv_and_salt)
  attr_encryptor :github_access_token

  has_many :projects
  has_many :tracked_branches, through: :projects
  has_many :test_jobs, through: :tracked_branches

  GITHUB_REQUIRED_SCOPES = %w(user:email repo)

  def github_client
    if github_access_token.present?
      client = Octokit::Client.new(access_token: github_access_token)

      (client.scopes & GITHUB_REQUIRED_SCOPES).size == 2 ? client : nil
    end
  rescue Octokit::Unauthorized
    return
  end
end
