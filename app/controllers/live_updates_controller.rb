# This controller and the Broadcaster model are part of the implementation of
# push events. The implementation is base on the idea described in this article:
# http://www.pivotaltracker.com/community/tracker-blog/one-weird-trick-to-switch-from-polling-to-push
class LiveUpdatesController < ApplicationController
  # Checks if the current_user is authorized for live updates on the requested
  # resource and directs the socket.io server to include the specified socket
  # to any updates on this resource. The server is informed through Redis
  # Pub/Sub system.
  def subscribe
    klass, ids = params[:resource_ids].split("#")
    ids = ids.split(",").map(&:to_i)

    if whitelisted_params.include?(klass) && params[:uid].present?
      resources = klass.constantize.where(id: ids)

      resources.each do |resource|
        begin
          authorize! :read_live_updates, resource

          # User is authorized for this resource, therefore add socket_id to
          # subscribers.
          Broadcaster.subscribe(
            params[:uid], resource.redis_live_update_resource_key
          )

        rescue CanCan::AccessDenied
          render json: { errors: 'Access denied' },
            status: :unprocessable_entity and return
        end
      end
      head :ok
    else
      render json: { errors: 'Param is not whitelisted' },
        status: :unprocessable_entity
    end
  end

  def whitelisted_params
    [Project, TestRun, TestJob].map(&:to_s)
  end
end
