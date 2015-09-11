class OrganizationRole < ActiveRecord::Base
  has_many :organization_user_roles
  has_many :assigned_users, through: :organization_user_roles, source: :user
  has_many :assigned_organizations, through: :organization_user_roles,
    source: :organization
end
