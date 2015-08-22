module ApplicationHelper
  def brand_name
    'Testributor'
  end

  def job_class(status)
    case status
    when 'Pending'
      'warning'
    when 'Passed'
      'success'
    when 'Failed'
      'danger'
    else
      ''
    end
  end

  def controller_and_action
    "#{controller_path.split("/").join(' ')} #{action_name.gsub('_','-')}"
  end

  def page_data_attrs
    {
      "js-class" => controller_path.camelize.gsub("::", "."),
      "js-method" => action_name.camelize(:lower)
    }
  end

  def github_oauth_authorize_url
    Octokit.authorize_url(Octokit.client_id, scope: 'user:email,repo')
  end
end
