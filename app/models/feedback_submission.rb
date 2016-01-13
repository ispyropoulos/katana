class FeedbackSubmission < ActiveRecord::Base
  CATEGORIES = [
    "Report a bug / UX issue",
    "Make a suggestion",
    "Other"
  ]
  RATINGS = {
    "Very bad" => 1,
    "Bad" => 2,
    "Neutral" => 3,
    "Good" => 4,
    "Very good" => 5
  }
  validates :body, presence: true
  belongs_to :user
end
