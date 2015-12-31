# This widget should be used in any page that need live updates on resources
# resouceId is something like TestRun#1 where 1 is the id of the TestRun.
# callback is the method that will be called with the websocket message as
# an argument.
Testributor.Widgets ||= {}
class Testributor.Widgets.LiveUpdates
  constructor: (resourceIds, callback)->
    @resourceIds = resourceIds
    @callback = callback

    subscribe = (uid, resourceIds)->
      # Subscribe to live updates
      $.post(Testributor.Config.LIVE_UPDATES_SUBSCRIBE_URL, {
        uid: uid, resource_ids: resourceIds
      }).done((data)->
      )

    # Trigger "connect" manually if socket is already connected to subscribe
    if(socket = io(Testributor.Config.SOCKETIO_URL))["id"]
      subscribe(socket["id"], @resourceIds)

    # NOTE: Don't move this definition away from the connection or it might not
    # run (if connect event comes before we set the callback).
    # TODO: If our code subscribes multiple times to the same resource, multiple
    # callbacks will be connected to the "connect" event. On reconnection, multiple
    # subscribe requests will be fired. It would be better if we kept a set of
    # resources on which we have already subscribed (on the socket object?).
    # We would not attach a new callback if an otherone already exists for the
    # same resource.
    socket.on("connect", =>
      subscribe(socket["id"], @resourceIds)
    )

    resourceName = resourceIds.split("#")[0]
    parsedResourceIds = _.map(resourceIds.split("#")[1].split(","), (id) -> parseInt(id))
    for resourceId in parsedResourceIds
      socket.on("#{resourceName}##{resourceId}", (msg)=>
        @callback(msg)
      )
