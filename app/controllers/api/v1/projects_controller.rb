module Api
  module V1
    class ProjectsController < ApiController
      # We ignore counting active workers for "current" action to avoid showing
      # the workers active during initialization. Initialization
      # take some time to complete and workers will appear as inactive
      # for some seconds.

      skip_before_action :worker_report, only: :setup_data

      def setup_data
        render json: {
          current_project:
            ActiveModelSerializers::SerializableResource.new(current_project),
          current_worker_group:
            ActiveModelSerializers::SerializableResource.new(current_worker_group)
        }
      end

      def beacon
        head :ok
      end
    end
  end
end
