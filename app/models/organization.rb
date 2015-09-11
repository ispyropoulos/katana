class Organization < ActiveRecord::Base
  belongs_to :user # this is the owner of the organization

  has_many :organization_user_roles
  has_many :organization_roles, through: :organization_user_roles
  has_many :participating_users, through: :organization_user_roles, source: :user

  validates :name, :user, presence: true

  before_save :check_user_limit

  private

  # Don't let an organization be assigned to a user if organizations limit
  # has been reached
  def check_user_limit
    if user &&
      user.organizations_limit < Organization.where(user_id: user.id).count + 1
      self.errors.add(:base, "Organization limit reached")

      return false
    end
  end
end
