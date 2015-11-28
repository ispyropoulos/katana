Testributor.Pages ||= {}
class Testributor.Pages.TrackedBranches
  show: ->
    debugger
    url = $(["data-url"])
    source = new EventSource('')
    source.addEventListener 'newTestJob', (e) ->
      debugger
      alert e.data
