$(document).on 'ready', ->
  # Register Handlebars Helpers
  new Testributor.Helpers.Helper

  # Disable all links that have 'disabled' class
  $('a.disabled').click (e) ->
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
