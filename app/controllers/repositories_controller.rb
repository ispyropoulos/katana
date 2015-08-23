class RepositoriesController < ApplicationController
  # TODO : Implement permissions
  def show
    repo_url = Repositories::GitRepository.all[params[:id]]
    @repository = Repositories::GitRepository.new(repo_url, nil)
  end

  def index
    render json: Repositories::GitRepository.all.to_json
  end
end
