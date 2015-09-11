class OrganizationUserRole < ActiveRecord::Base
  belongs_to :user
  belongs_to :organization
  belongs_to :organization_role

  validates :organization, :user, :organization_role, presence: true
end
