class Organization < ActiveRecord::Base
  belongs_to :user # this is the owner of the organization

  has_many :organization_user_roles
  has_many :organization_roles, through: :organization_user_roles
  has_many :participating_users, through: :organization_user_roles, source: :user

  validates :name, :user, presence: true
end
