require 'test_helper'

class FeedbackSubmissionsControllerTest < ActionController::TestCase
  describe "#create" do
    let(:user) { FactoryGirl.create(:user) }
    let(:category) { 'pakallis@gmail.com' }
    let(:body) { 'hello' }
    let(:rating) { 1 }

    before do
      sign_in :user, user
    end

    it "creates FeedbackSubmission if valid" do
      xhr :post, :create,
        { feedback_submission: { category: category, body: body, rating: rating } }

      assert_response :ok

      feedback_submission = FeedbackSubmission.last
      feedback_submission.category.must_equal category
      feedback_submission.body.must_equal body
      feedback_submission.rating.must_equal rating
      feedback_submission.user_id.must_equal user.id
    end

    it "sends e-mail if valid" do
      xhr :post, :create,
        { feedback_submission: { category: category, body: body, rating: rating } }

      assert_response :ok

      ActionMailer::Base.deliveries.wont_be :empty?
    end

    it "doesn't create FeedbackSubmission if invalid" do
      xhr :post, :create, { feedback_submission: { category: category, body: '' } }

      assert_response :unprocessable_entity
      FeedbackSubmission.last.must_equal nil
    end
  end
end
