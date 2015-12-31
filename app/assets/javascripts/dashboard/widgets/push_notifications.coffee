Testributor.Widgets ||= {}
class Testributor.Widgets.PushNotifications
  constructor: ->
    @authorize()

  authorize: ->
    unless @_authorized()
      Notification.requestPermission()
      false
    true

  notify: (title, text, iconUrl, clickUrl)->
    if !Notification
      console.log "Desktop notifications aren't available in your browser. Try Chrome."
      return

    if @_authorized()
      notification = new Notification(title, icon: iconUrl, body: text)
      notification.onclick = ->
        window.open clickUrl
    else
      @authorize()

  _authorized: ->
    Notification.permission == 'granted'
