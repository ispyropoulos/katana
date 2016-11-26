module UsersApi
  module V1
    class CommitsController < UsersApiController
      def status
        unless params[:id].length >= 6
          render plain: "Specify a commit hash with at least the first 6 characters",
            status: :bad_request
          return
        end

        project =
          current_user.participating_projects.find_by(name: params[:project])

        unless project
          render plain: "Project with name '#{params[:project]}' does not exist",
            status: :not_found
          return
        end

        test_run =
          project.test_runs.where("commit_sha LIKE ?", "#{params[:id]}%").
          order("created_at DESC").first

        unless test_run
          render plain: "No Build found for the specified commit", status: 404
          return
        end

        render json: {
          status: test_run.status.text
        }
      end
    end
  end
end
