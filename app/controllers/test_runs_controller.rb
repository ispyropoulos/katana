class TestRunsController < DashboardController
  include Controllers::EnsureProject

  # skip devise method
  skip_before_action :authenticate_user!, :only => [:show, :index]
  before_action :set_test_run, only: [:show, :update, :destroy, :retry]
  before_action :authorize_resource!

  def index
    if params[:branch_id]
      @tracked_branch = TrackedBranch.non_private.find_by(id: params[:branch_id].to_i)
      if current_user
        @tracked_branch ||= current_user.tracked_branches.find_by(id: params[:branch_id])
      end
    elsif params[:branch]
      @tracked_branch ||= TrackedBranch.non_private.
        find_by(branch_name: params[:branch], project: current_project)
      if current_user
        @tracked_branch ||= current_project.tracked_branches.
          find_by(branch_name: params[:branch], project: current_project)
      end
    else
      @tracked_branch ||= current_project.tracked_branches.find_by(branch_name: 'master')
    end


    if @tracked_branch
      @test_runs = current_project.test_runs.
        where(tracked_branch: @tracked_branch).
        limit(TrackedBranch::OLD_RUNS_LIMIT).order("created_at DESC")
    else
      @test_runs = current_project.test_runs.
        limit(TrackedBranch::OLD_RUNS_LIMIT).order("created_at DESC")
    end
    @statuses = TestRun.test_job_statuses(@test_runs.select(&:id))
    @user_can_manage_runs = can?(:manage, @test_runs.first)
  end

  def show
    @test_jobs = @test_run.test_jobs.order('status DESC, sent_at ASC, chunk_index ASC, created_at ASC, id ASC')
    @user_can_manage_run = can?(:manage, @test_run)
  end

  def create
    # Specifying the branch means the user want the latest commit on that
    # else she must specify the commit_sha
    if params[:branch_id]
      branch_id = current_project.tracked_branches.find(params[:branch_id]).id
    else
      commit_sha = params[:test_run].try(:[],:commit_sha)
    end

    manager = RepositoryManager.new(current_project)
    test_run = manager.create_test_run!(
      { tracked_branch_id: branch_id, initiator_id: current_user.id,
        commit_sha: commit_sha })

    if test_run
      head :ok and return if request.xhr?
      flash[:notice] = 'Your build is being setup'
      redirect_back(fallback_location: redirect_back_fallback_path)
    else
      head :ok and return if request.xhr?
      flash[:alert] =  manager.errors.join(', ')
      redirect_back(fallback_location: redirect_back_fallback_path)
    end
  end

  def update
    if @test_run.update(test_run_params)
      head :ok and return if request.xhr?
      redirect_back(fallback_location: redirect_back_fallback_path)
    else
      head 422 and return if request.xhr?
      render :edit
    end
  end

  def retry
    unless @test_run.retry?
      redirect_back(fallback_location: redirect_back_fallback_path, 
                    alert: "Retrying ##{@test_run.id} test run is not allowed at this time")
    end

    # TODO: Consider delete_all here or a custom retry method on TestRun
    # TestJob#destroy trigger the after_commit hook for TestRun update status.
    # This means we update the status N times just to destroy everything.
    @test_run.test_jobs.destroy_all
    @test_run.setup_worker_uuid = nil
    @test_run.status = TestStatus::SETUP
    @test_run.save!

    RepositoryManager.new(current_project).schedule_test_run_setup(@test_run)

    Broadcaster.publish(
      @test_run.redis_live_update_resource_key,
      { test_run_id: @test_run.id,
        event: 'TestRunRetry'
    })

    head :ok and return if request.xhr?
    redirect_back(fallback_location: redirect_back_fallback_path,
                  notice: 'The build will soon be retried')
  end

  def destroy
    authorize! :destroy, @test_run

    @test_run.destroy

    redirect_back(fallback_location: redirect_back_fallback_path, 
                  notice: 'Test run was successfully cancelled.')
  end

  private

  def authorize_resource!
    action_map = {
      retry: :update,
      update: :update,
      destroy: :destroy,
      index: :read,
      show: :read,
      create: :create }

    authorize!(action_map[action_name.to_sym], @test_run || TestRun)
  end

  def set_test_run
    @test_run = current_project.test_runs.find(params[:id]).decorate
  end

  def test_run_params
    params.permit(:status)
  end

  def project_is_public?
    current_project.is_public?
  end
end
