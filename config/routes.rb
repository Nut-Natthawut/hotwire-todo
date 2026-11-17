Rails.application.routes.draw do
 
  get "up" => "rails/health#show", as: :rails_health_check
  resources :tasks, except: :show
  root "tasks#index"
end
