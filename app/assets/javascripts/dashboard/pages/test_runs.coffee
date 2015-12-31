Testributor.Pages ||= {}
class Testributor.Pages.TestRuns
  index: ->
    testRunTemplate = HandlebarsTemplates["test_runs/test_run"]
    progressBar = new Testributor.Widgets.ProgressBar(display_stats: true)
    Handlebars.registerPartial('progress_bar', HandlebarsTemplates["progress_bar"])

    new Testributor.Widgets.LiveUpdates("TestRun#" + $('.progress')[0].id, (msg) ->
      if msg.retry
        progressBar.reset(msg.test_run_id)
      else
        testJob = msg.test_job
        testRun = msg.test_run
        progressBar.update(testJob.test_run_id, testJob.html_class)
        data = {
          id: testRun.id,
          active: if progressBar.toggle($("##{testRun.id}")) then 'progress-bar-striped active',
          statuses: testRun.statuses
        }

        testRun.progressBarData = data
        $("#test-run-#{testRun.id}").replaceWith(testRunTemplate(testRun))
        $('[data-toggle="popover"]').popover()
    )
    $('[data-toggle="popover"]').popover()

  show: ->
    jobTemplate = HandlebarsTemplates["test_jobs/test_job"]
    errorTemplate = HandlebarsTemplates["test_jobs/error"]
    testRunId = $('[data-test-run-id]').data('test-run-id')
    userIsAdmin = $('[data-admin-user]').data('admin-user')

    progressBar = new Testributor.Widgets.ProgressBar(display_stats: false)
    Testributor.Widgets.LiveUpdates("TestRun#" + testRunId, (msg) ->
      if msg.retry
        progressBar.reset(msg.test_run_id)
      else
        if msg.test_run.terminal_status
          $("#test_run_retry_button").show()

        testJob = $.extend(msg.test_job, admin: userIsAdmin)
        $tr = $("#test-job-#{testJob.id}")
        $newTr = $(jobTemplate(testJob))
        $tr.replaceWith($newTr)
        $error = $(errorTemplate(testJob))
        if testJob.unsuccessful
          $error.insertAfter($newTr)
        $newTr.animate({backgroundColor: '#fff'}, 2000)
        progressBar.update(testJob.test_run_id, testJob.html_class)
    )
    $('[data-toggle="popover"]').popover()

    #show all button
    $('.show-all-area').on 'click', (e) ->
      if $('#show_all').is(':checked')
        $("div[id^='error']").collapse('show')
      else
        $("div[id^='error']").collapse('hide')
