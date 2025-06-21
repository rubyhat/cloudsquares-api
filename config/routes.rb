# config/routes.rb
Rails.application.routes.draw do
  if Rails.env.development? || Rails.env.test?
    mount Rswag::Ui::Engine => "/api-docs"
    mount Rswag::Api::Engine => "/api-docs"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # Аутентификация
      post "auth/login",           to: "auth#login"
      post "auth/refresh",         to: "auth#refresh"
      post "auth/logout",          to: "auth#logout"
      post "auth/register-agent",  to: "auth#register_agent_admin"
      post "auth/register-user",   to: "auth#register_user"

      # Текущий пользователь
      get :me, to: "users#me"
      resources :users

      # Агентства недвижимости
      resources :agencies, only: %i[index show create update destroy]
      patch "agencies/:id/change_plan", to: "agencies#change_plan"

      #  Настройки агентства
      get "my_agency/setting", to: "agency_settings#my_agency"
      resources :agency_settings, only: %i[show update]

      # Тарифные планы агентств
      resources :agency_plans, only: %i[index show create update destroy]

      # Категории объектов недвижимости
      resources :property_categories, only: %i[index show create update destroy] do
        get :characteristics, on: :member
      end

      # Характеристики недвижимости
      resources :property_characteristics do
        get :categories, on: :member
      end

      # Привязка характеристик к категориям
      resources :property_category_characteristics, only: %i[create destroy]

      # 🏠 Объекты недвижимости
      resources :properties
    end
  end
end
