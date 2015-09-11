class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable and :omniauthable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable

  belongs_to :invited_by, class_name: "Organization"
  has_many :test_jobs
  has_many :organizations # on which this user is an owner
  has_many :organization_user_roles
  has_many :organization_roles, through: :organization_user_roles
  has_many :participating_organizations, through: :organization_user_roles,
    source: :organization

  def roles_on_organization(organization)
    organization_roles.
      where(organization_user_roles: { organization_id: organization.id })
  end
end
