class TrackedBranchesController < DashboardController
  include Controllers::EnsureProject

  def new
    manager = RepositoryManager.new({ project: current_project })
    branch_names_to_reject = current_project.tracked_branches.map(&:branch_name)

    @branches = manager.fetch_branch_names.reject do |branch_name|
      branch_name.in?(branch_names_to_reject)
    end.map { |b| TrackedBranch.new(branch_name: b.name) }
  end

  def create
    tracked_branch = current_project.
      tracked_branches.create(branch_name: params[:branch_name])

    if tracked_branch.persisted?
      manager = RepositoryManager.new({project: tracked_branch.project})
      test_run =
        manager.create_test_run!({ tracked_branch_id: tracked_branch.id })

      if test_run
        flash[:notice] =
          "Successfully started tracking '#{tracked_branch.branch_name}' branch."
      else
        tracked_branch.destroy!
        flash[:alert] = manager.errors.join(', ')
      end
    else
      flash[:alert] = tracked_branch.errors.full_messages.join(', ')
    end

    redirect_to project_path(current_project)
  end

  def destroy
    tracked_branch = current_project.tracked_branches.find(params[:id])
    if tracked_branch.destroy
      flash[:notice] = "#{tracked_branch.branch_name} branch was removed"
      redirect_to project_path(current_project)
    else
      flash[:alert] = "Can't remove #{tracked_branch.branch_name} branch"
      redirect_to project_branch_path(current_project, tracked_branch)
    end
  end

  private

  def branch_params
    params.require(:tracked_branch).permit(:branch_name)
  end
end
