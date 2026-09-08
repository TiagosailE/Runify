Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations",
    passwords: "users/passwords"
  }

  root "welcome#index"

  get "privacidade", to: "pages#privacy", as: :privacy_policy
  get "termos", to: "pages#terms", as: :terms_of_use
  get "sobre", to: "pages#about", as: :about_page

  get "dashboard", to: "home#index", as: :dashboard

  get "profile", to: "profile#index", as: :profile
  patch "profile/update", to: "profile#update", as: :profile_update

  get "strava/connect", to: "strava#connect", as: :strava_connect
  get "strava/callback", to: "strava#callback", as: :strava_callback
  post "strava/sync", to: "strava#sync", as: :sync_strava
  delete "strava/disconnect", to: "strava#disconnect", as: :strava_disconnect

  resources :notifications, only: [ :index ] do
    member do
      post :mark_as_read
    end
    collection do
      post :mark_all_as_read
    end
  end

  resources :pacers do
    member do
      delete :leave
    end
    collection do
      post :join_by_code
    end
  end

  get "history", to: "history#index", as: :history

  get "activities/new", to: "activities#new", as: :new_activity
  post "activities", to: "activities#create", as: :activities
  delete "activities/:id", to: "activities#destroy", as: :activity

  get "settings", to: "settings#index", as: :settings
  post "settings/update_password", to: "settings#update_password", as: :update_password_settings
  post "settings/toggle_theme", to: "settings#toggle_theme", as: :toggle_theme_settings
  post "settings/toggle_notifications", to: "settings#toggle_notifications", as: :toggle_notifications_settings
  get "settings/get_settings_state", to: "settings#get_settings_state", as: :get_settings_state
  get "settings/export_data", to: "settings#export_data", as: :export_data_settings
  delete "settings/delete_account", to: "settings#delete_account", as: :delete_account_settings

  get "training", to: "training#index", as: :training_index
  post "training/generate", to: "training#generate", as: :generate_training
  get "training/:id", to: "training#show", as: :training_show
  post "training/:id/complete", to: "training#complete", as: :training_complete
  post "training/:id/feedback", to: "training#feedback", as: :training_feedback

  get "onboarding/step1", to: "onboarding#step1", as: :onboarding_step1
  post "onboarding/step2", to: "onboarding#step2", as: :onboarding_step2
  get "onboarding/step2", to: "onboarding#step2_view", as: :onboarding_step2_view
  post "onboarding/complete", to: "onboarding#complete", as: :onboarding_complete

  # Acesso exige users.admin = true, concedido so por rake -- nunca por tela.
  namespace :admin do
    root "users#index"
    resources :users, only: [ :index, :show ] do
      member do
        delete :disconnect_strava
        post :cancel_training_plan
        post :send_password_reset
      end
    end
    resources :audit_logs, only: [ :index ]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
