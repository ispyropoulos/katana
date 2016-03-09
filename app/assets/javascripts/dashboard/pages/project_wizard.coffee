Testributor.Pages ||= {}
class Testributor.Pages.ProjectWizard
  update: ->
    $(".multi-select").select2()
  show: ()->
    $(".multi-select").select2()

    $fetchRepos = $('.js-fetch-repos')
    currentPath = $fetchRepos.data('current-path')
    if $fetchRepos
      @performAjaxFor(currentPath, @attachFetchEvent)

    $('.provider-box input[type="radio"]').on "change", (e)->
      $target = $(e.currentTarget)
      $target.closest('form').find('label').removeClass('selected')
      $target.closest('label').addClass('selected')

  performAjaxFor: (url, callback) =>
    Pace.ignore =>
      jqxhr = $.ajax(
        url: url,
        beforeSend: ->
          $('.js-fetching-repos').show()
      ).done((data)->
        $('.js-fetch-repos').html(data).fadeIn('slow')
      ).fail(->
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
