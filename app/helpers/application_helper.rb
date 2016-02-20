module ApplicationHelper
  def meta_title
    "Testributor: Parallel Testing for Ruby on Rails, Python, Javascript and more."
  end

  def meta_description
    "Testributor will help you slice up your test suite and transparently "\
    "run all its “pieces” in parallel, on your computers or ours."
  end

  def controller_and_action
    "#{controller_path.split("/").join(' ')} #{action_name.gsub('_','-')}"
  end

  def page_data_attrs
    {
      "js-class" => controller_path.camelize.gsub("::", "."),
      "js-method" => action_name.camelize(:lower),
      "admin-user" => current_user.try(:admin?).try(:to_json),
      "test-run-ids" => current_user.try(:test_runs).try(:pluck, :id),
      "desktop-notifications-enabled" => desktop_notifications_enabled
    }
  end

  def github_oauth_authorize_url
    Octokit.authorize_url(Octokit.client_id, scope: 'user:email,repo',
                         redirect_uri: github_callback_url)
  end

  def wizard_step_class(step)
    class_str = "current" if current_step?(step)
    class_str = "disabled" if future_step?(step)
    class_str = "done" if past_step?(step)

    class_str
  end

  def grouped_languages_options
    DockerImage.languages.group_by(&:standardized_name).
      map do |group, languages|
      [
        group, languages.map do |language|
          [language.public_name, language.id]
        end
      ]
    end
  end

  def conditions_for_active_project
    [
      current_page?(project_path(current_project)),
      controller_name == 'test_runs'
    ]
  end

  def technologies_options
    DockerImage.technologies.map do |technology|
      [technology.public_name, technology.id]
    end
  end

  def flash_messages
    if flash[:notice]
      html = <<-HTML
        <div class='alert alert-info'>
          #{flash[:notice]}
        </div>
        </br>
      HTML
      flash_message = html.html_safe
    end

    if flash[:alert]
      html = <<-HTML
        <div class='alert alert-danger'>
          #{flash[:alert]}
        </div>
        </br>
      HTML
      flash_message = html.html_safe
    end

    flash_message
  end

  def link_to_if_with_block condition, options, html_options={}, &block
    if condition
      link_to options, html_options, &block
    else
      capture &block
    end
  end

  private

  def desktop_notifications_enabled
    if current_user && current_project
      ProjectParticipation.find_by(user: current_user, project: current_project).
        enable_desktop_notifications.to_json
    end
  end
end
