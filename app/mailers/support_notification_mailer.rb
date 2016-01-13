class SupportNotificationMailer < ApplicationMailer
  default to: "info@testributor.com"

  def feedback_received(feedback_submission_id)
    @feedback_submission = FeedbackSubmission.find(feedback_submission_id)
    mail(from: @feedback_submission.user.email, subject: "[Feedback form] " + @feedback_submission.category)
  end
end
