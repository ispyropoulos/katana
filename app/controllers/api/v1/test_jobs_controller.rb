module Api
  module V1
    class TestJobsController < ApiController
      # PATCH test_jobs/bind_next_batch
      # To avoid race conditions, the selected jobs should be marked as running
      # in an atomic operation.
      # http://stackoverflow.com/questions/11532550/atomic-update-select-in-postgres
      def bind_next_batch
        sample_job = current_project.test_jobs.
          where(test_runs: { status: [TestStatus::RUNNING, TestStatus::QUEUED]}).
          where(status: TestStatus::QUEUED).
          order("test_runs.status DESC, test_runs.created_at DESC, test_jobs.chunk_index ASC").first

        if sample_job.blank?
          render json: [], include: "test_run.project" and  return
        end

        preferred_jobs_sql = current_project.test_jobs.where(
          test_run_id: sample_job.test_run_id,
          chunk_index: sample_job.chunk_index).to_sql

        sql = <<-SQL
          UPDATE test_jobs SET status = #{TestStatus::RUNNING}
          FROM (#{preferred_jobs_sql} FOR UPDATE) t
          WHERE test_jobs.id = t.id
          RETURNING test_jobs.*
        SQL
        test_jobs = nil
        TestJob.transaction { test_jobs = TestJob.find_by_sql(sql) }

        render json: test_jobs, include: "test_run.project"
      end

      # TODO: When the reporter sends reports for cancelled/destroyed test_runs
      # send back a list of cancelled/missing test_run ids so that the worker
      # can cancel any left jobs for those runs.
      def batch_update
        jobs = params[:jobs].map do |id, json|
          [id.to_i, JSON.parse(json)] rescue nil
        end.compact
        jobs = Hash[jobs]
        job_ids = params[:jobs].keys

        # Store the TestRun ids of any missing or cancelled TestRuns to let
        # the worker know that they should be removed from the jobs queue.
        test_run_ids = jobs.values.map{|j| j["test_run_id"].to_i}.uniq
        # Anything not cancelled is a keeper (we still want them to run)
        test_run_id_keepers =
          current_project.test_runs.where("status != ?", TestStatus::CANCELLED).
          where(id: test_run_ids).pluck(:id)
        missing_or_cancelled_test_run_ids = test_run_ids - test_run_id_keepers

        current_project.test_jobs.running.where(id: job_ids).each do |job|
          begin
            job_params = jobs[job.id].keep_if do |k,v|
                %w(result status id result runs assertions failures errors
                   skips sent_at_seconds_since_epoch worker_in_queue_seconds
                   worker_command_run_seconds).include?(k)
            end
          rescue Exception => e
            render json: { error: e.message,
              delete_test_runs:  missing_or_cancelled_test_run_ids } and return
          end

          job.update!(job_params.merge(reported_at: Time.current))
          Broadcaster.publish(job.test_run.redis_live_update_resource_key,
                              { test_job: job.serialized_job, test_run: job.test_run.reload.serialized_run }.to_json)
        end

        render json: { delete_test_runs:  missing_or_cancelled_test_run_ids }

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
