module Api
  module V1
    class TestJobsController < ApplicationController
      before_action :doorkeeper_authorize!
      respond_to :json

      def index
        respond_with current_project.test_jobs
      end

      private
      def current_project
        @current_project ||= Project.find(doorkeeper_token.resource_owner_id)
      end
    end
  end
end
