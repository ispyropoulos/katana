class FeedbackSubmissionsController < ApplicationController
  def create
    return unless request.xhr?
    feedback_submission = FeedbackSubmission.new(feedback_submission_params)
    if feedback_submission.save
      success_message = "We received your feedback. Thank you!"
      SupportNotificationMailer.
        feedback_received(feedback_submission.id).deliver_now
      render json: success_message, status: :ok
    else
      render json: feedback_submission.errors.full_messages.first,
        status: :unprocessable_entity
    end
  end

  private

  def feedback_submission_params
    params.require(:feedback_submission).
      permit(:category, :body, :rating).merge(user_id: current_user.id)
  end
end
