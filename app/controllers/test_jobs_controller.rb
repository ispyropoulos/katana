class TestJobsController < DashboardController
  include Controllers::EnsureProject

  # Here, we use update to retry a failed test job
  def update
    @test_job = TestJob.find(params[:id])
    if @test_job.update(test_job_params)
      $redis.publish('testRun.update', 'test_job_update')
      redirect_to :back, notice: 'Test job was successfully updated.'
    end
  end
  private

  def test_job_params
    params.permit(:status)
  end
end
