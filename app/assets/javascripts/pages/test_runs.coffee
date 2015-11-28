Testributor.Pages ||= {}
class Testributor.Pages.TestRuns
  index: ->
    eventsUrl = $("[data-events-url]").data("events-url")
    source = new EventSource(eventsUrl)
    source.addEventListener 'testRun.update', (e) ->
      console.log e.data


  show: ->
    eventsUrl = $("[data-events-url]").data("events-url")
    source = new EventSource(eventsUrl)
    source.addEventListener 'testRun.update', (e) ->
      testJob = $.parseJSON(e.data)
      console.log testJob.status
      if testJob.status == 3
        status = "<span class='label label-danger'>Failed</span>"
      if testJob.status == 2
        status = "<span class='label label-success'>Passed</span>"

      $testJobRow = $("#test-job-#{testJob.id}")
      $testJobRow.find(".status").html(status)
      $testJobRow.find(".errors").html(testJob.test_errors)
      $testJobRow.find(".failures").html(testJob.failures)
      $testJobRow.find(".tests").html(testJob.count)
      $testJobRow.find(".assertions").html(testJob.assertions)
      completedAt = new Date(testJob.completed_at).toISOString()
      runningTime = "#{testJob.total_running_time} s"
      $testJobRow.find(".completed_at").html(completedAt)
      $testJobRow.find(".running_time").html(testJob.total_running_time)

