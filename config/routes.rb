Rails.application.routes.draw do
  devise_for :users
  
  root "welcome#index"
  
  get "dashboard", to: "home#index", as: :dashboard
  
  get "profile", to: "profile#index", as: :profile
  patch "profile/update", to: "profile#update", as: :profile_update
  
  get "strava/connect", to: "strava#connect", as: :strava_connect
  get "strava/callback", to: "strava#callback", as: :strava_callback
  delete "strava/disconnect", to: "strava#disconnect", as: :strava_disconnect
  
  get "onboarding/step1", to: "onboarding#step1", as: :onboarding_step1
  post "onboarding/step2", to: "onboarding#step2", as: :onboarding_step2
  get "onboarding/step2", to: "onboarding#step2_view", as: :onboarding_step2_view
  post "onboarding/complete", to: "onboarding#complete", as: :onboarding_complete
  
  get "up" => "rails/health#show", as: :rails_health_check
end