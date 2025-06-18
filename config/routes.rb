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

      # Создание нового пользователя B2B в роли agent_admin
      post "auth/register-agent", to: "auth#register_agent_admin"

      # Создание нового пользователя B2C в роли user
      post "auth/register-user", to: "auth#register_user"

      # Текущий пользователь
      get :me, to: "users#me"

      # Пользователи
      resources :users

      # Агентства недвижимости
      resources :agencies, only: %i[index show create update destroy]

      # Тарифные планы для агентств недвижимости
      resources :agency_plans, only: %i[index show create update destroy]

      # Обновление тарифного плана у агентства недвижимости
      patch "agencies/:id/change_plan", to: "agencies#change_plan"

      # Настройки Агентства
      get "my_agency/setting", to: "agency_settings#my_agency"
      resources :agency_settings, only: [:show, :update]

      # Категории объектов недвижимости
      resources :property_categories, only: %i[index show create update destroy]

      # Характеристики недвижимости
      resources :property_characteristics

    end
  end

end
