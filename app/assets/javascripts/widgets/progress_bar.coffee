Testributor.Widgets ||= {}
class Testributor.Widgets.ProgressBar
  constructor: (options = {})->
    @display_stats = options["display_stats"]
    @progressBarTemplate = HandlebarsTemplates["progress_bar"]
    Handlebars.registerPartial('progress_bar', @progressBarTemplate)

    _.each($('.progress'), (value, key, list) =>
      $currentBar = $(value)
      progressBarData = {
        statuses: $currentBar.data(),
        active: if _this.toggle($currentBar) then 'progress-bar-striped active',
        id: $currentBar.attr('id')
      }
      $currentBar.parent().html(@progressBarTemplate(progressBarData))
    )

  update: (id, status) =>
    $progressBar = $("##{id}")
    testJobsLength = $progressBar.data('length')
    statusSize = if $progressBar.data(status) then (Number($progressBar.data(status)) + 1) else 1
    $progressBar.data(status, statusSize)
    width = (statusSize / testJobsLength) * 100
    $progressBar.find(".progress-bar-#{status}").animate({ width: "#{width}%"}, 50)
    $progressBar.siblings().find(".#{status}").text(statusSize)
    unless @toggle($progressBar)
      $progressBar.find('.progress-bar-striped.active').removeClass('progress-bar-striped active')

  toggle: (currentBar) ->
    $currentBar = $(currentBar)
    data = $currentBar.data()
    data['length'] != data['pink'] + data['danger'] + data['success']

  reset: (id) =>
    $currentBar = $("##{id}")
    progressBarData = {
      id: id,
      statuses: {
        pink: 0,
        danger: 0,
        success: 0,
        length: $currentBar.data('length')
      }
    }
    $currentBar.parent().html(@progressBarTemplate(progressBarData))
