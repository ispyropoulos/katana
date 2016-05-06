class TopicSubscriber
  include CanCan::Ability

  def initialize(subscriber, socket_id)
    @socket_id = socket_id
    @ability = Ability.new(subscriber)
  end

  # Can accept multiple topics.
  # E.g. subscribe({TrackedBranch: [1,2,3], Project: [3,4,5]})
  def subscribe(requested_subscriptions)
    return {} unless @socket_id
    
    subscriptions = {}
    requested_subscriptions.each do |klass, ids|
      next unless whitelisted_classes.include?(klass)
      resources = klass.constantize.where(id: ids)
      topics_to_subscribe = resources.select do |resource|
        @ability.can?(:read_live_updates, resource)
      end.map(&:id)
      subscriptions[klass] = topics_to_subscribe
    end
    request_subscriptions(subscriptions)

    subscriptions
  end

  private

  def request_subscriptions(subscriptions)
    subscriptions_array = subscriptions.map do |klass, ids|
      ids.map { |id| "#{klass}##{id}" }
    end.flatten

    Broadcaster.subscribe(@socket_id, subscriptions_array)
  end

  def whitelisted_classes
    [User, Project, TrackedBranch, TestRun, TestJob].map(&:to_s)
  end
end
