require 'sidekiq/web'

Rails.application.routes.draw do
  use_doorkeeper

  authenticate :user, lambda { |u| u.admin? } do
      mount Sidekiq::Web => '/sidekiq'
  end

  devise_for :projects
  devise_for :users, :controllers => { :omniauth_callbacks => "callbacks" }

  namespace :admin do
    get :become
  end

  namespace :api, default: { format: 'json' } do
    namespace :v1 do
      resources :projects, only: [] do
        collection do
          get :current
          post :beacon
        end
      end
      resources :test_runs
      resources :test_jobs, only: [] do
        collection do
          patch :bind_next_batch
          patch :batch_update
        end
      end
    end
  end

  get 'oauth/github_callback' => 'oauth#github_callback', as: :github_callback
  post 'webhooks/github' => 'webhooks#github', as: :github_webhook

  authenticated :user do
    root to: "dashboard#index", as: :authenticated_root
  end

  unauthenticated do
    root to: "home#index"
  end

  get 'invitation/accept' => "user_invitations#accept", as: :accept_user_invitation
  # If you put this in the defaults(project: nil) block above it will erase
  # the "project" param from create action resulting in error.
  resources :projects, only: [:show, :update, :destroy] do
    resource :settings, only: [:show] do
      get :worker_setup
      get :notifications
    end

    member do
      get :instructions
      get :docker_compose
    end

    resources :test_runs, only: [:show, :update, :destroy] do
      member do
        post :retry
      end
    end

    resources :test_jobs, only: [] do
      put :retry
    end

    resources :tracked_branches, only: [:new, :create, :destroy],
      path: :branches, as: :branches do
        resources :test_runs, only: [:index, :create, :new]
    end

    resources :project_files, as: :files, path: :files, except: [:edit]
    resources :project_participations, as: :participations, path: :users
    resources :user_invitations, path: :invitations,
      except: [:index, :show, :update, :edit] do
      member do
        post :resend
      end
    end
  end

  resources :email_submissions, only: :create
  resources :feedback_submissions, only: :create
  resources :project_wizard do
    member do
      get :fetch_repos
    end
  end

  get 'pages/:id' => 'pages#show', as: :pages

  post 'live_updates/subscribe' => "live_updates#subscribe",
    as: :live_updates_subscribe
end
