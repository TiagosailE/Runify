Rails.application.routes.draw do
  devise_for :users
  
  root "welcome#index"
  
  get "dashboard", to: "home#index", as: :dashboard
  
  get "profile", to: "profile#index", as: :profile
  patch "profile/update", to: "profile#update", as: :profile_update
  
  get "strava/connect", to: "strava#connect", as: :strava_connect
  get "strava/callback", to: "strava#callback", as: :strava_callback
  post "strava/sync", to: "strava#sync", as: :sync_strava
  delete "strava/disconnect", to: "strava#disconnect", as: :strava_disconnect
  
  get "notifications", to: "notifications#index", as: :notifications
  post "notifications/:id/mark_as_read", to: "notifications#mark_as_read", as: :mark_as_read_notification
  post "notifications/mark_all_as_read", to: "notifications#mark_all_as_read", as: :mark_all_as_read_notifications
  
  get "pacers", to: "pacers#index", as: :pacers
  get "pacers/new", to: "pacers#new", as: :new_pacer
  post "pacers/create", to: "pacers#create", as: :create_pacer
  get "pacers/:id", to: "pacers#show", as: :pacer
  post "pacers/:id/join", to: "pacers#join", as: :join_pacer
  delete "pacers/:id/leave", to: "pacers#leave", as: :leave_pacer
  
  get "history", to: "history#index", as: :history
  
  get "settings", to: "settings#index", as: :settings
  post "settings/update_password", to: "settings#update_password", as: :update_password_settings
  post "settings/toggle_theme", to: "settings#toggle_theme", as: :toggle_theme_settings
  post "settings/toggle_notifications", to: "settings#toggle_notifications", as: :toggle_notifications_settings
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
  
  get "up" => "rails/health#show", as: :rails_health_check
end