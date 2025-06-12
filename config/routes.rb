Rails.application.routes.draw do
  if Rails.env.development? || Rails.env.test?
    mount Rswag::Ui::Engine => "/api-docs"
    mount Rswag::Api::Engine => "/api-docs"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # Аутентификация
      post "auth/login",   to: "auth#login"
      post "auth/refresh", to: "auth#refresh"
      post "auth/logout",  to: "auth#logout"

      # Текущий пользователь
      get :me, to: "users#me"

      # Пользователи
      resources :users

      # Агентства недвижимости
      resources :agencies, only: %i[index show create update destroy]
    end
  end

end
