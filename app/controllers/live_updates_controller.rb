# This controller and the Broadcaster model are part of the implementation of
# push events. The implementation is base on the idea described in this article:
# http://www.pivotaltracker.com/community/tracker-blog/one-weird-trick-to-switch-from-polling-to-push
class LiveUpdatesController < ApplicationController
  # Checks if the current_user is authorized for live updates on the requested
  # resources and directs the socket.io server to include the specified socket
  # to any updates on these resources. The server is informed through Redis
  # Pub/Sub system.
  # @param params[:uid] -> the socket id
  # @param params[:subscriptions] -> A hash which contains the requested resources to subscribe. E.g.
  # params[:subscriptions] = 
  # { 
  #   "TrackedBranch" => [1,2,3],
  #   "Project" => [1,2],
  #   "TestRun" => [34],
  #   "TestJob" => [57,78]
  # }
  def subscribe
    if current_user.present?
      successful_subscriptions = current_user.
        subscribe(params[:subscriptions], params[:uid])
      render json: { successful_subscriptions: successful_subscriptions }
    else
      render nothing: true, status: :unauthorized
    end
  end
end
