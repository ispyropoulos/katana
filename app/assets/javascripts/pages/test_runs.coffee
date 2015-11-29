Testributor.Pages ||= {}
class Testributor.Pages.TestRuns
  index: ->
    eventsUrl = $("[data-events-url]").data("events-url")
    source = new EventSource(eventsUrl)
    source.addEventListener 'testRun.update', (e) ->
      console.log e.data


  show: ->
    jobTemplate = """
      <tr id="test-job-<%= id %>" >
        <td><%= command %></td>
        <td class="status">
          <span class="<%= status_css_class %>"><%= status_text %></span>
        </td>
        <td class="errors"><%= test_errors %></td>
        <td class="failures"><%= failures %></td>
        <td class="count"><%= count %></td>
        <td class="assertions"><%= assertions %></td>
        <td class="skips"><%= skips %></td>
        <td class="completed_at"><%= completed_at %></td>
        <td class="running_time">
          <%= total_running_time %>
        </td>
        <td>
          <a class="#btn btn-primary btn-xs m-b-5" rel="nofollow" data-method="put" href="<%= retry_url %>"><i class="fa fa-refresh"></i>
          <span>Retry</span>
          </a>
        </td>
      </tr>
    """
    compiled = _.template(jobTemplate)
    eventsUrl = $("[data-events-url]").data("events-url")
    source = new EventSource(eventsUrl)
    source.addEventListener 'testRun.update', (e) ->
      testJob = $.parseJSON(e.data)
      $tr = $("#test-job-#{testJob.id}")
      $tr.replaceWith(compiled(testJob))
