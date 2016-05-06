# This widget should be used in any page that need live updates on provided resources
# subscriptions is an object which contains all requested subscriptions in the following format:
# subscripttions = 
# {
#   "TrackedBranch": [1,2],
#   "Project": [1],
#   "TestJob": [7]
# }
# callback is the method that will be called with the websocket message as
# an argument.
Testributor.Widgets ||= {}
class Testributor.Widgets.LiveUpdates
  constructor: (subscriptions, callback)->
    @subscriptions = subscriptions
    @callback = callback

    subscribe = (uid, subscriptions)->
      # Subscribe to live updates
      $.post(Testributor.Config.LIVE_UPDATES_SUBSCRIBE_URL, {
        uid: uid, subscriptions: subscriptions
      }).done((data)->
      )

    # Trigger "connect" manually if socket is already connected to subscribe
    if(socket = io(Testributor.Config.SOCKETIO_URL))["id"]
      subscribe(socket["id"], @subscriptions)

    # NOTE: Don't move this definition away from the connection or it might not
    # run (if connect event comes before we set the callback).
    # TODO: If our code subscribes multiple times to the same resource, multiple
    # callbacks will be connected to the "connect" event. On reconnection, multiple
    # subscribe requests will be fired. It would be better if we kept a set of
    # resources on which we have already subscribed (on the socket object?).
    # We would not attach a new callback if an otherone already exists for the
    # same resource.
    socket.on("connect", =>
      subscribe(socket["id"], @subscriptions)
    )

    _.each(subscriptions, (ids, resource) =>
      _.each(ids, (id) =>
        socket.on("#{resource}##{id}", (msg)=>
          @callback(msg)
        )
      )
    )
