class TestJobFilesController < DashboardController
  # Here, we use update to retry a failed
  # test job file
  def update
    @test_job_file = TestJobFile.find(params[:id])
    if @test_job_file.update(test_job_file_params)
      redirect_to :back, notice: 'Test job file was successfully updated.'
    else
      render :edit
    end
  end

  private

  def test_job_file_params
    params.permit(:status)
  end
end
