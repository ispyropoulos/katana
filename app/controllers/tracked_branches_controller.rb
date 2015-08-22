class TrackedBranchesController < DashboardController
  def new
    if client = current_user.github_client
      @project = current_user.projects.includes(:tracked_branches).
        find(params[:project_id])
      @branches = client.branches(@project.repository_id).
        reject { |b| b.name.in?(@project.tracked_branches.map(&:branch_name)) }.
        map { |b| TrackedBranch.new(branch_name: b.name) }
    end
  end

  def create
    if branch_params[:branch_name].present? && (client = current_user.github_client)
      project = current_user.projects.find(params[:project_id])
      branch = client.branch(project.repository_id, branch_params[:branch_name])
      tracked_branch = project.tracked_branches.create!(branch_name: branch.name)
      flash[:notice] = "Successfull started tracking '#{tracked_branch.branch_name}' branch."
    end

    redirect_to project_path(params[:project_id])
  end

  private
  def branch_params
    params.require(:tracked_branch).permit(:branch_name)
  end
end
