class TestRunsController < DashboardController
  include Controllers::EnsureProject

  # skip devise method
  skip_before_filter :authenticate_user!, :only => [:show, :index]
  before_action :set_test_run, only: [:show, :update, :destroy, :retry]
  before_action :authorize_resource!

  def index
    @tracked_branch = TrackedBranch.non_private.where(id: params[:branch_id]).try(:first)
    if current_user
      @tracked_branch ||= current_user.tracked_branches.find(params[:branch_id])
    end
    @test_runs = @tracked_branch.test_runs.
      limit(TrackedBranch::OLD_RUNS_LIMIT).order("created_at DESC")
    @statuses = TestRun.test_job_statuses(@test_runs.select(&:id))
    @user_can_manage_runs = can?(:manage, @test_runs.first)
  end

  def show
    @test_jobs = @test_run.test_jobs.order('status DESC, sent_at ASC, chunk_index ASC, created_at ASC, id ASC')
    @user_can_manage_run = can?(:manage, @test_run)
  end

  def create
    branch = current_project.tracked_branches.find(params[:branch_id])
    manager = RepositoryManager.new(branch.project)
    test_run = manager.create_test_run!({ tracked_branch_id: branch.id })
    if test_run
      flash[:notice] = 'Your build is being setup'
      head :ok and return if request.xhr?
      redirect_to :back
    else
      flash[:alert] =  manager.errors.join(', ')
      head :ok and return if request.xhr?
      redirect_to :back
    end
  end

  def update
    if @test_run.update(test_run_params)
      head :ok and return if request.xhr?
      redirect_to :back, notice: 'Test run was successfully updated.'
    else
      head 422 and return if request.xhr?
      render :edit
    end
  end

  def retry
    authorize! :update, @test_run

    unless @test_run.retry?
      return redirect_to :back, alert: "Retrying ##{@test_run.id} test run is not allowed at this time"
    end

    @test_run.test_jobs.destroy_all
    @test_run.status = TestStatus::SETUP
    @test_run.save!
    RepositoryManager::TestRunSetupJob.perform_later(@test_run.id)
    Broadcaster.publish(
      @test_run.redis_live_update_resource_key,
      { retry: true,
        test_run_id: @test_run.id,
        event: 'TestRunRetry'
    })

    head :ok and return if request.xhr?
    redirect_to :back, notice: 'The Build will soon be retried'
  end

  def destroy
    authorize! :destroy, @test_run

    tracked_branch_id = @test_run.tracked_branch_id
    @test_run.destroy
    redirect_to project_branch_test_runs_url(current_project, tracked_branch_id),
      notice: 'Test run was successfully cancelled.'
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
