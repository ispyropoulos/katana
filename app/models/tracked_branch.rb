class TrackedBranch < ActiveRecord::Base
  belongs_to :project
  has_many :test_jobs, dependent: :destroy
end
