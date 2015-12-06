class TestRunsController < DashboardController
  include ActionController::Live
  include Controllers::EnsureProject

  before_action :set_test_run, only: [:show, :update, :destroy, :retry]

  def index
    @tracked_branch = current_user.tracked_branches.find(params[:branch_id])
  end

  def show
    @run = TestRun.find(params[:id])
    @test_jobs = @run.test_jobs.order('status DESC, created_at ASC, id ASC')
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
    @test_run.test_jobs.destroy_all
    @test_run.build_test_jobs
    @test_run.save
    redirect_to :back, notice: 'Test run was successfully updated.'
  end

  def destroy
    tracked_branch_id = @test_run.tracked_branch_id
    @test_run.destroy
    redirect_to project_branch_test_runs_url(current_project, tracked_branch_id),
      notice: 'Test run was successfully cancelled.'
  end

  def events
    response.headers["Content-Type"] = "text/event-stream"
    redis = Redis.new(db: "katana_#{Rails.env}")
    redis.psubscribe('testRun.update') do |on|
      on.pmessage do |pattern, event, data|
        response.stream.write("event: #{event}\n")
        response.stream.write("data: #{data}\n\n")
      end
    end
  rescue IOError
    logger.info "Stream closed"
  ensure
    redis.quit
    response.stream.close
  end

  private

  def set_test_run
    @test_run = TestRun.find(params[:id])
  end

  def test_run_params
    params.permit(:status)
  end
end
