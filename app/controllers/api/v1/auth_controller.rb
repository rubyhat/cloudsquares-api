# frozen_string_literal: true

module Api
  module V1
    # Контроллер аутентификации и регистрации пользователей.
    #
    # Изменения:
    # - B2C регистрация ТОЛЬКО в контексте агентства: нужен agency_id ИЛИ property_id.
    # - При регистрации B2C создаём Person, User(:user), Contact(в агентстве), Customer(service_type: :buy).
    # - JWT кладём agency_id этого контекста.
    # - login поддерживает agency_id/property_id в запросе, чтобы выбрать контекст для токена.
    #
    # Новое:
    # - POST /api/v1/auth/register-agent-with-agency — атомарная регистрация B2B:
    #   Person -> User(:agent_admin) -> Agency(plan) -> UserAgency(is_default) -> Contact.
    class AuthController < BaseController
      skip_before_action :authenticate_user!
      before_action :authenticate_user!, only: [:logout]

      # POST /api/v1/auth/login
      #
      # Аутентификация по телефону и паролю.
      # Необязательные параметры agency_id / property_id задают агентский контекст, который поместим в токен.
      #
      # @param phone [String]
      # @param password [String]
      # @param agency_id [UUID, optional]
      # @param property_id [UUID, optional]
      def login
        raw_phone   = login_params[:phone].to_s.strip
        password    = login_params[:password]
        agency_id   = login_params[:agency_id].presence
        property_id = login_params[:property_id].presence

        normalized = ::Shared::PhoneNormalizer.normalize(raw_phone)
        unless normalized.present?
          return render_error(
            key: "auth.invalid_phone",
            message: "Некорректный номер телефона",
            status: :unauthorized,
            code: 401
          )
        end

        person = Person.find_by(normalized_phone: normalized)
        user   = person && User.find_by(person_id: person.id)

        unless user&.authenticate(password)
          return render_error(
            key: "auth.invalid_credentials",
            message: "Неверный логин или пароль",
            status: :unauthorized,
            code: 401
          )
        end

        # Определяем агентский контекст для токена
        token_agency_id = nil
        if property_id
          prop = Property.find_by(id: property_id)
          token_agency_id = prop&.agency_id
        elsif agency_id
          token_agency_id = Agency.where(id: agency_id).pick(:id)
        end

        tokens = Auth::JwtService.generate_tokens(user, agency_id: token_agency_id)
        Auth::TokenStorageRedis.save(user_id: user.id, iat: tokens[:iat])

        render json: {
          access_token:  tokens[:access_token],
          refresh_token: tokens[:refresh_token]
        }, status: :ok
      end

      # POST /api/v1/auth/refresh
      #
      # Проверяет refresh_token; если валиден — выдаёт новую пару токенов.
      # Можно опционально передать agency_id, чтобы переопределить контекст.
      def refresh
        payload = Auth::JwtService.decode_and_verify(params[:refresh_token])

        if payload.present? && payload["type"] == "refresh"
          user = User.find_by(id: payload["sub"])

          if user && Auth::TokenStorageRedis.valid?(user_id: user.id, iat: payload["iat"])
            token_agency_id = params[:agency_id].presence
            tokens = Auth::JwtService.generate_tokens(user, agency_id: token_agency_id)
            Auth::TokenStorageRedis.save(user_id: user.id, iat: tokens[:iat])

            render json: {
              access_token:  tokens[:access_token],
              refresh_token: tokens[:refresh_token]
            }, status: :ok
          else
            render_error(
              key: "auth.invalid_refresh_token",
              message: "Refresh token is invalid or expired",
              status: :unauthorized,
              code: 401
            )
          end
        else
          render_invalid_token
        end
      end

      # POST /api/v1/auth/logout
      #
      # Удаляет refresh-токен пользователя из Redis.
      def logout
        token   = request.headers["Authorization"]&.split&.last
        payload = Auth::JwtService.decode(token)

        Auth::TokenStorageRedis.clear(user_id: payload["sub"]) if payload && payload["sub"].present?

        render_success(key: "auth.logout", message: "Вы вышли из системы")
      end

      # POST /api/v1/auth/register-user
      #
      # Публичная регистрация B2C-покупателя В КОНТЕКСТЕ АГЕНТСТВА.
      # Требуется agency_id или property_id.
      def register_user
        rp = register_user_params

        raw_phone  = rp[:phone].to_s.strip
        normalized = ::Shared::PhoneNormalizer.normalize(raw_phone)
        unless normalized.present?
          return render_error(
            key: "auth.invalid_phone",
            message: "Некорректный номер телефона",
            status: :unprocessable_entity,
            code: 422
          )
        end

        # Вычисляем агентство из property_id или agency_id
        property_id = rp[:property_id].presence
        agency_id   = rp[:agency_id].presence

        if property_id
          property = Property.find_by(id: property_id)
          return render_not_found("Объект недвижимости не найден", "properties.not_found") unless property
          target_agency = property.agency
        elsif agency_id
          target_agency = Agency.find_by(id: agency_id)
          return render_not_found("Агентство не найдено", "agencies.not_found") unless target_agency
        else
          return render_error(
            key: "auth.agency_required",
            message: "Требуется agency_id или property_id для регистрации покупателя",
            status: :unprocessable_entity,
            code: 422
          )
        end

        ActiveRecord::Base.transaction do
          # 1) Person (уникален по normalized_phone)
          person = Person.find_or_initialize_by(normalized_phone: normalized)
          if person.persisted? && User.exists?(person_id: person.id)
            return render_error(
              key: "auth.phone_taken",
              message: "Пользователь с таким телефоном уже зарегистрирован",
              status: :unprocessable_entity,
              code: 422
            )
          end
          person.save! unless person.persisted?

          # 2) User (роль :user)
          user = User.new(
            person_id:             person.id,
            email:                 rp[:email],
            password:              rp[:password],
            password_confirmation: rp[:password_confirmation],
            role:                  :user,
            country_code:          rp[:country_code],
            is_active:             true
          )
          user.save!

          # 3) Contact в рамках агентства
          contact = Contact.find_or_initialize_by(agency_id: target_agency.id, person_id: person.id)
          contact.first_name  = rp[:first_name].presence || contact.first_name || "—"
          contact.last_name   = rp[:last_name]   if rp.key?(:last_name)
          contact.middle_name = rp[:middle_name] if rp.key?(:middle_name)
          contact.email       = rp[:email]       if rp.key?(:email)
          if rp.key?(:extra_phones)
            contact.extra_phones = Array(rp[:extra_phones]).map { |p| ::Shared::PhoneNormalizer.normalize(p) }.reject(&:blank?)
          end
          contact.is_deleted = false if contact.has_attribute?(:is_deleted)
          contact.save!

          # 4) Customer для этого контакта
          Customer.find_or_create_by!(agency_id: target_agency.id, contact_id: contact.id) do |c|
            c.service_type = :buy
            c.user_id      = user.id
            c.is_active    = true
          end

          # 5) Токены с агентским контекстом
          tokens = Auth::JwtService.generate_tokens(user, agency_id: target_agency.id)
          Auth::TokenStorageRedis.save(user_id: user.id, iat: tokens[:iat])

          render json: {
            user:          UserSerializer.new(user, scope: user, current_agency: target_agency),
            access_token:  tokens[:access_token],
            refresh_token: tokens[:refresh_token]
          }, status: :created
        end
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      rescue ActiveRecord::RecordNotUnique
        render_error(
          key: "auth.phone_taken",
          message: "Пользователь с таким телефоном уже зарегистрирован",
          status: :unprocessable_entity,
          code: 422
        )
      end

      # POST /api/v1/auth/register-agent-with-agency
      #
      # Новая атомарная регистрация B2B: создаёт User(:agent_admin) + Agency + UserAgency + Contact.
      # В случае успеха сразу возвращает токены с контекстом созданного агентства.
      #
      # Тело запроса:
      # {
      #   "user": {
      #     "phone": "77020000002",
      #     "email": "b2b@example.com",
      #     "password": "UserPassword1@",
      #     "password_confirmation": "UserPassword1@",
      #     "country_code": "RU",
      #     "first_name": "Иван",
      #     "last_name": "Алексеев",
      #     "middle_name": "Сергеевич"
      #   },
      #   "agency": {
      #     "title": "ИП Алексеев",
      #     "slug": "ip-alekseev",          // можно не передавать
      #     "custom_domain": null,           // опционально
      #     "agency_plan_id": null           // если nil — возьмём дефолтный план
      #   }
      # }
      #
      # Ответ: { user, agency, access_token, refresh_token }
      def register_agent_with_agency
        payload   = register_agent_with_agency_params
        user_p    = (payload[:user]   || {}).to_h
        agency_p  = (payload[:agency] || {}).to_h

        # Выполняем регистрацию через сервис
        user, agency = ::Auth::RegisterAgentWithAgency.new(
          user_params:   user_p,
          agency_params: agency_p
        ).call

        tokens = Auth::JwtService.generate_tokens(user, agency_id: agency.id)
        Auth::TokenStorageRedis.save(user_id: user.id, iat: tokens[:iat])

        render json: {
          user:          UserSerializer.new(user, scope: user),
          access_token:  tokens[:access_token],
          refresh_token: tokens[:refresh_token]
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        # Передаём точные ошибки конкретной модели (User/Agency и т.д.)
        render_validation_errors(e.record)
      rescue ActiveRecord::RecordNotFound => e
        render_not_found(e.message)
      rescue ActiveRecord::RecordNotUnique
        render_error(
          key: "auth.phone_or_slug_taken",
          message: "Телефон или slug агентства уже заняты",
          status: :unprocessable_entity,
          code: 422
        )
      end

      # DEPRECATED: POST /api/v1/auth/register-agent
      # Оставляем временно, но не используем на фронте. Позднее удалить.
      def register_agent_admin
        create_agent_admin
      end

      private

      # Разрешённые параметры B2C регистрации
      def register_user_params
        params.require(:user).permit(
          :phone, :email, :password, :password_confirmation, :country_code,
          :first_name, :last_name, :middle_name,
          :agency_id, :property_id,
          extra_phones: []
        )
      end

      # Разрешённые параметры логина
      def login_params
        params.permit(:phone, :password, :agency_id, :property_id)
      end

      # Разрешённые параметры для B2B регистрации с агентством (новый эндпоинт)
      def register_agent_with_agency_params
        params.permit(
          user:   %i[phone email password password_confirmation country_code first_name last_name middle_name],
          agency: %i[title slug custom_domain agency_plan_id]
        )
      end

      # ===== Ниже — ВРЕМЕННАЯ обёртка для старого эндпоинта (DEPRECATED) =====

      # Вспомогательный метод регистрации агентского админа (без агентства)
      def create_agent_admin
        rp = register_user_params
        raw_phone  = rp[:phone].to_s.strip
        normalized = ::Shared::PhoneNormalizer.normalize(raw_phone)
        unless normalized.present?
          return render_error(
            key: "auth.invalid_phone",
            message: "Некорректный номер телефона",
            status: :unprocessable_entity,
            code: 422
          )
        end

        ActiveRecord::Base.transaction do
          person = Person.find_or_initialize_by(normalized_phone: normalized)
          if person.persisted? && User.exists?(person_id: person.id)
            return render_error(
              key: "auth.phone_taken",
              message: "Пользователь с таким телефоном уже зарегистрирован",
              status: :unprocessable_entity,
              code: 422
            )
          end
          person.save! unless person.persisted?

          user = User.new(
            person_id:             person.id,
            email:                 rp[:email],
            password:              rp[:password],
            password_confirmation: rp[:password_confirmation],
            role:                  :agent_admin,
            country_code:          rp[:country_code],
            is_active:             true
          )
          user.save!

          tokens = Auth::JwtService.generate_tokens(user, agency_id: nil)
          Auth::TokenStorageRedis.save(user_id: user.id, iat: tokens[:iat])

          render json: {
            user:          UserSerializer.new(user, scope: user),
            access_token:  tokens[:access_token],
            refresh_token: tokens[:refresh_token]
          }, status: :created
        end
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      rescue ActiveRecord::RecordNotUnique
        render_error(
          key: "auth.phone_taken",
          message: "Пользователь с таким телефоном уже зарегистрирован",
          status: :unprocessable_entity,
          code: 422
        )
      end
    end
  end
end
