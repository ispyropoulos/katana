$(document).on 'ready', ->
  # Register Handlebars Helpers
  new Testributor.Helpers.Helper

  # Disable all links that have 'disabled' class
  $('body').on 'click', 'a.disabled', (e) ->
    e.preventDefault()

  # Feedback form submission
  $("#new_feedback_submission").on("ajax:complete", (data, status, xhr) ->
    $feedbackBody = $("#feedback_submission_body")
    $formControl = $feedbackBody.closest(".form-group")
    $formControl.find(".error").remove()

    if status.status == 200
      $("#feedback-modal").modal("hide")
      $formControl.removeClass("has-error")
      swal("Success!", status.responseText, "success")
    else if status.status == 422 # Unprocessable entity
      $formControl.addClass("has-error")
      $formControl.append($("<label class='error'>#{status.responseText}</label>"))
    else
      swal(status.statusText, "An error occured. Try again later.", "error")
  )

  # Navbar cookie set
  $('.top-head .navbar-toggle').click ->
    # the code that adds/removes the class from aside element
    # has not been run yet since that code is imported before this code
    # so this event is attached last (so run first)
    $.cookie('left_panel_collapsed', !$('aside.left-panel').hasClass('collapsed'),
      { expires: 1000, path: '/' })

  renderFlash = (flashText, bootstrapClass) ->
    if flashText && $('.wraper').find('.alert-danger').length == 0
      flash = """
        <div class="alert alert-#{bootstrapClass} fade in">
          <a href="#" class="close" data-dismiss="alert" aria-label="close" title="close">×</a>
          <span>#{flashText}</span>
        </div>
      """
      $('.wraper').prepend(flash)
      setTimeout (->
        $('.wraper').find('.alert').remove()), 10000

  $(".js-remote-submission").on("ajax:complete", (data, status, xhr) ->
    if status.status == 200
      if status.responseText
        flashText = status.responseText
        renderFlash(flashText, 'info')
    else if status.status == 422 # Unprocessable entity
      flashText = status.responseText || 'We were not able to process your request.'
      renderFlash(flashText, 'danger')
  ).on("ajax:error", (data, status, xhr) ->
    defaultText = '<strong>Oops! Something went wrong.</strong> Please try reloading  page...'
    flashText = status.responseText || defaultText
    renderFlash(flashText, 'danger')
  )
