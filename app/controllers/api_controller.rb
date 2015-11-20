class ApiController < ActionController::Base
  before_action :doorkeeper_authorize!
  before_action :worker_report

  private

  def current_project
    @current_project ||= doorkeeper_token.application.owner
  end

  def worker_uuid
    uuid = request.headers['HTTP_WORKER_UUID']

    "project_#{current_project.id}_worker_#{uuid}" if uuid
  end

  #TODO: doorkeeper_token.update_column(:last_used_at, Time.current)
  #remove last_used_at from tokens ?
  def worker_report
    return false unless worker_uuid

    redis = Katana::Application.redis
    # Add an expiring key for the worker if not already there
    redis.setnx worker_uuid, worker_uuid
    redis.expire worker_uuid, Project::ACTIVE_WORKER_THRESHOLD_SECONDS
    # Add the worker to the project's set of workers
    redis.sadd current_project.workers_redis_key, worker_uuid
    # update the list of active workers on reports too to keep the list
    # size small. If we cleaned the list only on "reads" and a read did not come
    # for too long, we could end up bloating the memory (that might not be an
    # issue but better safe than sorry).
    current_project.update_active_workers
  end
end
