Rails.application.routes.draw do
  # Devise routes para autenticação
  devise_for :users
  
  # Página de boas-vindas
  root "welcome#index"
  
  # Home do usuário logado (vamos criar depois)
  get "dashboard", to: "home#index", as: :dashboard
  
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end