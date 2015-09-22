class Project < ActiveRecord::Base
  devise :database_authenticatable
  has_many :tracked_branches, dependent: :destroy
  before_create :set_secure_random
  has_one :oauth_application, class_name: 'Doorkeeper::Application', as: :owner, dependent: :destroy

  attr_accessor :fork

  private

  def set_secure_random
    self.secure_random = SecureRandom.hex

    #in case a secure random exists
    while Project.find_by_secure_random(self.secure_random)
      self.secure_random = SecureRandom.hex
    end
  end
end
