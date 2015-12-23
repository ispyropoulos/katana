class TestRunsController < DashboardController
  include Controllers::EnsureProject

  before_action :set_test_run, only: [:show, :update, :destroy, :retry]

  def index
    @tracked_branch = current_user.tracked_branches.find(params[:branch_id])
    @test_runs = @tracked_branch.test_runs.
      limit(TrackedBranch::OLD_RUNS_LIMIT).order("created_at DESC")
    @statuses = TestRun.test_job_statuses(@test_runs.select(&:id))
  end

  def show
    @test_jobs = @test_run.test_jobs.order('status DESC, created_at ASC, id ASC')
  end

  def create
    branch = current_project.tracked_branches.find(params[:branch_id])
    build_result = branch.build_test_run_and_jobs
    if build_result && branch.save
      flash[:notice] = 'Your build was added to queue'
    elsif build_result.nil?
      flash[:alert] = "#{branch.branch_name} doesn't exist anymore on github"
    else
      flash[:alert] = branch.errors.messages.values.join(', ')
    end

    redirect_to :back
  end

  def update
    if @test_run.update(test_run_params)
      redirect_to :back, notice: 'Test run was successfully updated.'
    else
      render :edit
    end
  end

  def retry
    unless @test_run.retry?
      return redirect_to :back, alert: "Retrying ##{@test_run.id} test run is not allowed at this time"
    end

    @test_run.test_jobs.destroy_all
    @test_run.build_test_jobs
    @test_run.save
    Broadcaster.publish(@test_run.redis_live_update_resource_key, { retry: true, test_run_id: @test_run.id })
    redirect_to :back, notice: 'Test run was successfully updated.'
  end

  def destroy
    tracked_branch_id = @test_run.tracked_branch_id
    @test_run.destroy
    redirect_to project_branch_test_runs_url(current_project, tracked_branch_id),
      notice: 'Test run was successfully cancelled.'
  end

  private

  def set_test_run
    @test_run = current_project.test_runs.find(params[:id])
  end

  def test_run_params
    params.permit(:status)
  end
end
