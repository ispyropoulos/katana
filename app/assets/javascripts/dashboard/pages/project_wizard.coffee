Testributor.Pages ||= {}
class Testributor.Pages.ProjectWizard
  fetchReposXhr: null
  update: ->
    @show()
  show: ()->
    $(".multi-select").select2()

    $('.provider-box input[type="radio"]').on "change", (e)=>
      $('.provider-list').addClass('hidden')
      $target = $(e.currentTarget)
      $target.closest('form').find('label').removeClass('selected')
      $target.closest('label').addClass('selected')

      currentPath = $target.data('current-path')
      if currentPath
        @performAjaxFor(currentPath, @attachFetchEvent)
      else if $target.val() == "bare_repo"
        @fetchReposXhr && @fetchReposXhr.abort() # quit any running
        $('.fetching-repos,.js-fetch-repos').hide()
        $('.bare-repo').show()

    $editor = $('#docker-compose-contents')
    if $editor.length > 0
      @editor = CodeMirror.fromTextArea($editor[0], {
        mode: {name: 'yaml'},
        lineNumbers: true,
        theme: 'neat',
        readOnly: true
      })

    $('#edit_project').on('change', 'select', (e)->
      $(e.currentTarget).submit()
    ).on("ajax:before", (e)=>
      $('.js-ajax-loader').show(100)
    ).on("ajax:success", (e, data, status, xhr)=>
      @editor.getDoc().setValue(data.docker_compose_yml_contents)
    ).on("ajax:complete", (e, elements)=>
      $('.js-ajax-loader').hide(100)
    )

    $waiting_for_worker = $('#waiting_for_worker')
    if $waiting_for_worker.length > 0
      [resource, id] = $waiting_for_worker
        .data('live-update-resource-id').split("#")
      subscriptions = {}
      subscriptions[resource] = [id]
      Testributor.Widgets.LiveUpdates(subscriptions, (msg) ->
        if msg.event == 'worker_added'
          $waiting_for_worker.remove()
          $("#done_button").show()
          setInterval(->
            $("#done_button").click()
          , 2000)
      )

    if ($checkedRadio = $('.provider-box input[type="radio"]:checked')).length > 0
      $checkedRadio.trigger("change")

  performAjaxFor: (url, callback) =>
    Pace.ignore =>
      @fetchReposXhr && @fetchReposXhr.abort() # quit the previous xhr
      $('.bare-repo').hide()

      @fetchReposXhr = $.ajax(
        url: url,
        beforeSend: ->
          $('.js-fetching-repos').show()
      ).done((data)->
        # If redirect_path is present it means that the provider's client
        # (e.g. GitHub, Bitbucket, etc.) was unauthorized, so follow the
        # redirection.
        window.location.href = data['redirect_path'] if data['redirect_path']

        $('.js-fetch-repos').html(data).fadeIn('slow')
        $('[data-toggle="tooltip"]').tooltip()
      ).fail((jqXHR, textStatus, errorThrown) ->
        $('.js-fetch-repos').
          append('Oops! Something went wrong. We are working on it.').
          fadeIn('slow')
      ).always(->
          $('.js-fetching-repos').hide()
          callback()
      )

  attachFetchEvent: () =>
    $('.pagination li a').on 'click', (e) =>
      e.preventDefault()
      _this.performAjaxFor($(e.currentTarget).attr('href'), _this.attachFetchEvent)
