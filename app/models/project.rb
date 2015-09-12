class Project < ActiveRecord::Base
  devise :database_authenticatable
  has_many :tracked_branches, dependent: :destroy
  before_create :create_secure_random
  after_create :create_oauth_application
  has_one :oauth_application, class_name: 'Doorkeeper::Application', as: :owner

  attr_accessor :fork


  private

  def create_oauth_application
    app = Doorkeeper::Application.new(
      :name => repository_id,
      :redirect_uri => 'http://testributor.com'
    )
    app.owner_id = self.id
    app.owner_type = 'Project'
    app.save
  end

  def create_secure_random
    self.secure_random = SecureRandom.hex
  end
>>>>>>> c0b7f01... after github integration changes
end
