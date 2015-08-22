Rails.application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".
  devise_for :users

  resources :projects, except: [:index, :edit, :update] do
    resources :tracked_branches, only: [:show, :new, :create], path: :branches,
      as: :branches
  end
  resources :test_job_files
  resources :test_jobs

  get 'dashboard' => 'dashboard#show', as: :dashboard
  get 'oauth/github_callback' => 'oauth#github_callback'
  post 'webhooks/github' => 'webhooks#github', as: :github_webhook

  root 'home#index'
end
