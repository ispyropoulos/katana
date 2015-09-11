class OrganizationUserRole < ActiveRecord::Base
  belongs_to :user
  belongs_to :organization
  belongs_to :organization_role

  validates :organization, :user, presence: true
end
