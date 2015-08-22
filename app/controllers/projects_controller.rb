class ProjectsController < DashboardController
  def show
    @project = current_user.projects.find(params[:id])
  end

  def new
    if client = current_user.github_client
      @repos = client.repos.
        reject do |r|
          r.fork? ||
            r.id.in?(current_user.projects.pluck(:repository_id)) ||
            r.full_name =~ /incrediblue/i
        end.map { |r| Project.new(repository_id: r.id, repository_name: r.name) }
    end
  end

  def create
    if project_params[:repository_id].present?
      if client = current_user.github_client

        # Retrieve the repo from GitHub to verify the validity
        # of the supplied identifier and create a new Project record.
        repo = client.repo(project_params[:repository_id].to_i)
        project = current_user.projects.create!(
          repository_provider: 'github',
          repository_id: repo.id,
          repository_name: repo.name
        )

        # Create a Webhook on the same GitHub repo for communicating
        # various events to our server and store its id with the Project.
        #
        # We listen for 'push' and 'delete' events
        # https://developer.github.com/webhooks/#events
        #
        # If the Webhook already exists, this step is skipped.
        # https://developer.github.com/v3/repos/hooks/#create-a-hook
        begin
          url = ENV['GITHUB_WEBHOOK_URL'] || github_webhook_url
          hook = client.create_hook(project.repository_id, 'web',
            {secret: ENV['GITHUB_WEBHOOK_SECRET'],
             url: url, content_type: 'json'}, events: %w(push delete))
        rescue Octokit::UnprocessableEntity => e
          if e.message =~ /hook already exists/i
            hooks = client.hooks(project.repository_id)
            hook = hooks.select do |h|
              h.config.url == url && h.events == %w(push delete)
            end.first
          else
            raise e
          end
        end
        project.update_attributes!(webhook_id: hook.id)

        flash[:notice] =
          "Successfully created '#{project.repository_name}' project."
      end
    end

    redirect_to dashboard_path
  end

  def destroy
    if client = current_user.github_client
      project = current_user.projects.find(params[:id])

      # Project pre-destroy actions
      # ---------------------------

      # Delete the associated Webhook from the GitHub repo,
      # unless still in use in other projects.
      unless Project.where(webhook_id: project.webhook_id).count(:id) > 1
        unless client.remove_hook(project.repository_id, project.webhook_id)
          # TODO Notify admins about the stale Webhook?
        end
      end

      project.destroy!
      # TODO Project post-destroy actions
      # e.g. Kill Amazon workers (Tasks, ECS instances, etc.)

      flash[:notice] =
        "Successfully destroyed '#{project.repository_name}' project."
    end

    redirect_to dashboard_path
  end

  private
  def project_params
    params.require(:project).permit(:repository_id)
  end
end
