require 'test_helper'

class TopicSubscriberTest < ActiveSupport::TestCase
  describe "#subscribe" do
    let(:first_project) { FactoryGirl.create(:project) }
    let(:last_project) do 
      FactoryGirl.create(:project, user: first_project.user)
    end
    let(:project_from_other_user) { FactoryGirl.create(:project) }
    let(:subscriptions) do
      {
        "Project" => [
          first_project.id, last_project.id, -1, 
          "random", nil, "", project_from_other_user.id
        ],
        "" => 1,
        "NoWhitelistedKlass" => 4
      }
    end

    before do
      first_project.user.update_column(:projects_limit, 3)
    end

    it "returns successful_subscriptions when socket_id is not nil" do
      socket_id = "1adf334a55s"
      topic_subscriber = TopicSubscriber.new(first_project.user, socket_id)
      successful_subscriptions = topic_subscriber.subscribe(subscriptions)
      successful_subscriptions.
        must_equal({ "Project" => [first_project.id, last_project.id] })
    end

    it "calls Broadcaster.subscribe with correct arguments on non nil socket_id" do
      socket_id = "1adf334a55s"
      topic_subscriber = TopicSubscriber.new(first_project.user, socket_id)
      successful_subscriptions_array = [
        "Project##{first_project.id}", "Project##{last_project.id}"
      ]
      Broadcaster.expects(:subscribe).
        with(socket_id, successful_subscriptions_array).once
      topic_subscriber.subscribe(subscriptions)
    end

    it "returns {} and doesn't subscribe when socket_id is nil" do
      socket_id = nil
      topic_subscriber = TopicSubscriber.new(first_project.user, socket_id)
      Broadcaster.expects(:subscribe).never
      successful_subscriptions = topic_subscriber.subscribe(subscriptions)
      successful_subscriptions.must_equal({})
    end
  end
end
