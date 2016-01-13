class SupportNotificationMailerPreview < ActionMailer::Preview
  def feedback_received
    @feedback_submission = FeedbackSubmission.last
  end
end
