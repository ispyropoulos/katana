module Api
  module V1
    class TestJobsController < ApiController
      # We use hardcoded value for now to avoid having worker's Manager
      # fetch multiple setup jobs with consecutive calls because they will
      # be considered as zero cost jobs. 20 seconds should be enough to
      # checkout a commit and return a list of files based on a regex.
      SETUP_JOB_COST = 20 # seconds.

      # PATCH test_jobs/bind_next_batch
      # To avoid race conditions, the selected jobs should be marked as running
      # in an atomic operation.
      # http://stackoverflow.com/questions/11532550/atomic-update-select-in-postgres
      def bind_next_batch
        test_jobs = next_batch # Always an array

        # If no job is pending, check if any TestRun needs setup.
        if test_jobs.empty? && (setup_data = setup_job_data).present?
          render json: setup_data
        else
          test_jobs.each do |job|
            Broadcaster.publish(job.test_run.redis_live_update_resource_key,
              { test_job: job.serialized_job,
                test_run: job.test_run.reload.serialized_run,
                event: 'TestJobUpdate'
              })
          end
          render json: test_jobs, include: "test_run.project"
        end
      end

      def batch_update
        test_run_ids = []
        jobs = params.require(:jobs).to_unsafe_hash.map do |id, json|
          if (test_run_id_for_setup = id.to_s.match(/^setup_job_(\d+)$/).try(:[], 1))
            test_run_ids << test_run_id_for_setup.to_i
            handle_test_run_setup(test_run_id_for_setup.to_i, json)
            nil # Nothing else to do. A background job will finish the setup.
          else
            [id.to_i, JSON.parse(json)] rescue nil
          end
        end.compact
        jobs = Hash[jobs]
        job_ids = params.require(:jobs).keys
        test_run_ids += jobs.values.map{|j| j["test_run_id"].to_i}.uniq

        # Store the TestRun ids of any missing or cancelled TestRuns to let
        # the worker know that they should be removed from the jobs queue.
        # Anything not cancelled is a keeper (we still want them to run)
        test_run_id_keepers =
          current_project.test_runs.where("status != ?", TestStatus::CANCELLED).
          where(id: test_run_ids).pluck(:id)
        missing_or_cancelled_test_run_ids = test_run_ids - test_run_id_keepers

        current_project.test_jobs.running.
          where(id: job_ids, worker_uuid: worker_uuid).each do |job|

          job_params = jobs[job.id].keep_if do |k,v|
            %w(result status id result runs assertions failures errors
               skips sent_at_seconds_since_epoch worker_in_queue_seconds
               worker_command_run_seconds).include?(k)
          end

          # Skips time attributes if already set (when retrying job)
          if job.sent_at.present?
            job_params.except!("sent_at_seconds_since_epoch")
          end
          if job.worker_in_queue_seconds.present?
            job_params.except!("worker_in_queue_seconds")
          end
          if job.worker_command_run_seconds.present?
            job_params.except!("worker_command_run_seconds")
          end
          job_params.merge!(reported_at: Time.current) if job.reported_at.nil?

          job.update!(job_params)
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

      def active_workers
        @active_workers ||= current_project.active_workers.
          map{|uuid| uuid.gsub(/project_#{current_project.id}_worker_/,'')}
      end

      def next_batch
        worker_condition_sql = ActiveRecord::Base.send(:sanitize_sql_array,
          ["test_jobs.status = ? OR "\
           "(test_jobs.status = ? AND test_jobs.worker_uuid NOT IN (?))",
           TestStatus::QUEUED, TestStatus::RUNNING, active_workers])

        sample_job_sql = current_project.test_jobs.
          where(test_runs: { status: [TestStatus::RUNNING, TestStatus::QUEUED]}).
          where(worker_condition_sql).
          order("test_runs.status DESC, test_runs.created_at DESC, test_jobs.chunk_index ASC").
          limit(1).to_sql

        sql = <<-SQL
          UPDATE test_jobs SET status = #{TestStatus::RUNNING}, worker_uuid = ?
          FROM (
            WITH preferred_jobs AS (#{sample_job_sql})
            SELECT test_jobs.* FROM test_jobs, preferred_jobs
            WHERE test_jobs.test_run_id = preferred_jobs.test_run_id
            AND test_jobs.chunk_index = preferred_jobs.chunk_index
          FOR UPDATE) t
          WHERE test_jobs.id = t.id
          /* Don't return all the jobs in the chunk. User might retried only
             one job from the chunk so some of the jobs might already be run. */
          AND (#{worker_condition_sql})
          RETURNING test_jobs.*
        SQL
        test_jobs = nil

        begin
          # Prevent "cannot set transaction isolation in a nested transaction"
          # error in tests (tests run inside a transaction)
          TestJob.transaction(isolation: Rails.env.test? ? nil : :serializable) do
            sql = ActiveRecord::Base.send(:sanitize_sql_array, [sql, worker_uuid.to_s])
            test_jobs = TestJob.find_by_sql(sql)
          end
        rescue ActiveRecord::StatementInvalid => e
          raise e unless e.original_exception.is_a?(PG::TRSerializationFailure)
          # Prevent all threads from retrying simultaneously
          sleep rand(0.020..1)
          retry
        end

        test_jobs
      end

      # Binds the "setup" of a TestRun and returns all data worker needs to
      # return the jobs.
      def setup_job_data
        return nil if current_project.repository_provider != "bare_repo"

        worker_condition_sql = ActiveRecord::Base.send(:sanitize_sql_array,
          ["setup_worker_uuid IS NULL OR setup_worker_uuid NOT IN (?)",
           active_workers])

        # http://dba.stackexchange.com/questions/69471/postgres-update-limit-1
        # http://www.practiceovertheory.com/blog/2013/07/06/distributed-locking-in-postgres/
        # TODO[Postgres 9.5]: Replace with the SKIP LOCKED mechanism described
        # on the first link.
        # TODO: It might be a solution for the next_batch transaction too.
        #   Try to use it on the sample_job_sql query.
        non_assigned_test_runs =
          current_project.test_runs.setting_up.
          where(worker_condition_sql).
          where("pg_try_advisory_xact_lock(id)").
          order("created_at ASC").limit(1)

        sql = <<-SQL
          UPDATE test_runs SET setup_worker_uuid = ?
          FROM (#{non_assigned_test_runs.to_sql} FOR UPDATE) t
          WHERE test_runs.id = t.id
          RETURNING test_runs.*
        SQL

        sql = ActiveRecord::Base.send(:sanitize_sql_array, [sql, worker_uuid])
        test_run = TestRun.find_by_sql(sql).first

        if test_run
          { type: "setup",
            sent_at_seconds_since_epoch: Time.current.utc.to_i,
            cost_prediction: SETUP_JOB_COST,
            test_run: { id: test_run.id, commit_sha: test_run.commit_sha },
            testributor_yml: current_project.testributor_yml_contents.to_s }
        else
          nil
        end
      end

      def handle_test_run_setup(test_run_id, json)
        if current_project.test_runs.where(id: test_run_id).exists?
          BareRepositoryManager::TestRunSetupJob.perform_later(test_run_id, json)
        end
      end

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
