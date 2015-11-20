module Api
  module V1
    class TestJobsController < ApiController
      # PATCH test_jobs/bind_next_batch
      # To avoid race conditions, the selected jobs should be marked as running
      # in an atomic operation.
      # http://stackoverflow.com/questions/11532550/atomic-update-select-in-postgres
      def bind_next_batch
        # Calculate workload and the number of queued or running jobs.
        # We try to equally distribute the load so we only send
        # workload / active_workers number of when jobs are requested.
        workload = current_project.test_jobs.
          where(status: [TestStatus::RUNNING,TestStatus::QUEUED]).count


        preferred_jobs_sql = current_project.test_jobs.queued.
          where(test_runs: { status: [TestStatus::RUNNING,TestStatus::QUEUED] }).
          order("test_runs.status DESC"). # Prefer "running" runs
          limit(workload / [current_project.active_workers.count, 1].max).to_sql

        sql = <<-SQL
          UPDATE test_jobs SET status = #{TestStatus::RUNNING}
          FROM (#{preferred_jobs_sql} FOR UPDATE) t
          WHERE test_jobs.id = t.id
          RETURNING test_jobs.*
        SQL

        render json: TestJob.find_by_sql(sql), include: "test_run.project"
      end

      # TODO: When the reporter sends reports for cancelled/destroyed test_runs
      # send back a list of cancelled/missing test_run ids so that the worker
      # can cancel any left jobs for those runs.
      def batch_update
        job_ids = params[:jobs].keys
        current_project.test_jobs.running.where(id: job_ids).each do |job|
          begin
            job_params = JSON.parse(params[:jobs][job.id.to_s]).keep_if do |k,v|
                %w(result status id result runs assertions failures errors
                   skips sent_at_seconds_since_epoch worker_in_queue_seconds
                   worker_command_run_seconds).include?(k)
            end
          rescue Exception => e
            puts e.message
            render json: { error: e.message } and return
          end

          job.update!(job_params.merge(reported_at: Time.current))
        end

        head 200

        # TODO: Consider updating all jobs with something like the following.
        # Make sure the fields are sanitized before sending to Postgres
=begin
        update_values = jobs_to_update.map do |id, j|
          [id] + %w(result runs assertions failures errors skips status).
            map{|k| j[k].to_i}.join(',')
        end.map{|v| "(#{v})"}

        sql = <<-SQL
          WITH new_values ("id", "result","runs","assertions","failures","errors","skips")
          AS (VALUES (#{update_values.join(',')})
          UPDATE "test_jobs" t SET result = nv.result,
            count = nv.runs, assertions = nv.assertions, failures = nv.failures,
            test_errors = nv.errors, skips = nv.skips, status = nv.status,
            "updated_at" = current_timestamp
          FROM new_values nv
          WHERE t."id" = nv."id"
          RETURNING t.*
        SQL
=end
      end

      private

      def test_job_params
        new_params = params.require(:test_job).permit(:result, :failures,
          :errors, :failures, :count, :assertions, :skips, :total_time, :status)

        # TODO: Remove this when we store total_time
        new_params.delete(:total_time)

        # Replace "errors" with "test_errors" because we can't have an
        # errors attribute (it conflicts with ActiveRecord's errors method)
        if errors = new_params.delete(:errors)
          new_params.merge(test_errors: errors)
        else
          new_params
        end
      end
    end
  end
end
