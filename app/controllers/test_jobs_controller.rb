class TestJobsController < DashboardController
  before_action :set_test_job, only: [:show, :update, :destroy]

  def index
    @test_jobs =
      current_user.tracked_branches.find(params[:tracked_branch_id]).test_jobs
  end

  def show
    @job = TestJob.find(params[:id])
    @job_files = @job.test_job_files.
      order("status DESC, started_at ASC, id ASC")
  end

  def create
    @test_job = TestJob.new(test_job_params)

    if @test_job.save
      redirect_to @test_job, notice: 'Test job was successfully created.'
    else
      render :new
    end
  end

  def update
    if @test_job.update(test_job_params)
      redirect_to @test_job, notice: 'Test job was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @test_job.destroy
    redirect_to test_jobs_url, notice: 'Test job was successfully cancelled.'
  end

  private
    def set_test_job
      @test_job = TestJob.find(params[:id])
    end

    def test_job_params
      params[:test_job].permit(
        :user_id, :git_ref, :status,
        :result_id, :created_at, :updated_at,
        :started_at, :completed_at)
    end
end
