Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      namespace :auth do
        post "send-code", to: "send_code#create"
        post "verify", to: "verify#create"
        post "complete-profile", to: "complete_profile#create"
      end
    end
  end
end
