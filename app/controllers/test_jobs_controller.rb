class TestJobsController < DashboardController
  include Controllers::EnsureProject

  before_action :authorize_resource!

  def retry
    @test_job = TestJob.find(params[:test_job_id])
    @test_job.retry!
    redirect_to :back, notice: 'Test job was successfully updated.'
  end

  def authorize_resource!
    action_map = { retry: :update }

    authorize!(action_map[action_name.to_sym], @test_job || TestJob)
  end
end
