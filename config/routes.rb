Rails.application.routes.draw do
  use_doorkeeper
  devise_for :users
  devise_for :projects

  resources :projects, except: [:index, :edit, :update] do
    resources :tracked_branches, only: [:show, :new, :create], path: :branches,
      as: :branches
  end
  resources :test_job_files
  resources :test_jobs

  namespace :api, default: { format: 'json' } do
    namespace :v1 do
      resources :test_jobs
    end
  end

  get 'dashboard' => 'dashboard#show', as: :dashboard
  get 'oauth/github_callback' => 'oauth#github_callback'
  post 'webhooks/github' => 'webhooks#github', as: :github_webhook

  root 'home#index'
end
