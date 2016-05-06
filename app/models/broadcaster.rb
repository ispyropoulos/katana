# This class is used so that katana can inform the backend endpoint
# for changes. In order to do this, we use the concept/metaphore of chat rooms.
# Each user(uid) subscribes to a room(resource_key) in order to listen
# for changes.
# Each time there is a change in the room(resource_key), only the interested
# user(uid) is informed about the change.
# Check the following links for more info:
#@see http://redis.io/topics/pubsub
#@see http://socket.io/docs/rooms-and-namespaces/
class Broadcaster
  LIVE_UPDATES_PUBLISH_CHANNEL = "LiveUpdates"
  SUBSCRIBERS_PUBLISH_CHANNEL = "RoomSubscriberAdd"

  # This method is called when we need to tell the backend endpoint
  # to subscribe a socket(uid) to a specific room(resource_key)
  # Check socket.io docs for more info on sockets
  def self.subscribe(uid, subscriptions)
    Katana::Application.redis.publish(SUBSCRIBERS_PUBLISH_CHANNEL,
      { socket_id: uid, rooms: subscriptions }.to_json)
  end

  # This method is called whenever there is a need to inform the backend
  # endpoint about changes(data) in a specific room(resource_key)
  def self.publish(resource_key, data)
    Katana::Application.redis.publish(LIVE_UPDATES_PUBLISH_CHANNEL,
      { room: resource_key, data: data }.to_json)
  end
end
