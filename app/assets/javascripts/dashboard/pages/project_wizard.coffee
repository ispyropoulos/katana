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
      jqxhr = $.ajax
        url: url,
        beforeSend: ->
          $('.js-fetching-repos').show()
        success: (data)->
          $('.js-fetch-repos').html(data).fadeIn('slow')
        fail: ->
          alert('Connection with github interrupted!')
          $('.js-fetch-repos').append('We were not able to complete this action.').fadeIn('slow')
        error: ->
          $('.js-fetch-repos').append('Oops! Something went wrong. We are working on it.').fadeIn('slow')
        complete: ->
          $('.js-fetching-repos').hide()
          callback()

  attachFetchEvent: () =>
    $('.pagination li a').on 'click', (e) =>
      e.preventDefault()
      _this.performAjaxFor($(e.currentTarget).attr('href'), _this.attachFetchEvent)
