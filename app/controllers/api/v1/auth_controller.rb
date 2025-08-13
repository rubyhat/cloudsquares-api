# frozen_string_literal: true

module Api
  module V1
    # Контроллер аутентификации и регистрации пользователей.
    #
    # Изменения:
    # - B2C регистрация ТОЛЬКО в контексте агентства: нужен agency_id ИЛИ property_id.
    # - При регистрации создаём Person, User(:user), Contact(в агентстве), Customer(service_type: :buy).
    # - JWT кладём agency_id этого контекста.
    # - login поддерживает agency_id/property_id в запросе, чтобы выбрать контекст для токена.
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
      #
      # Правила:
      # - Если передан property_id — agency_id берём из property.agency_id (перекрывает agency_id).
      # - Если ни agency_id, ни property_id не переданы — в токен пойдёт default_agency (для сотрудников)
      #   либо nil (для B2C), тогда фронт должен передавать agency_id/host отдельно или выбрать его позже.
      def login
        raw_phone  = login_params[:phone].to_s.strip
        password   = login_params[:password]
        agency_id  = login_params[:agency_id].presence
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
      # Сохраняем прежний агентский контекст (agency_id) из старого токена, если он был.
      def refresh
        payload = Auth::JwtService.decode_and_verify(params[:refresh_token])

        if payload.present? && payload["type"] == "refresh"
          user = User.find_by(id: payload["sub"])

          if user && Auth::TokenStorageRedis.valid?(user_id: user.id, iat: payload["iat"])
            # Сохраняем предыдущий контекст agency_id из старого access токена если фронт захочет его передать
            # (refresh сам по себе контекста не содержит; можно принять опционально agency_id)
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

        if payload && payload["sub"]
          Auth::TokenStorageRedis.clear(user_id: payload["sub"])
        end

        render_success(key: "auth.logout", message: "Вы вышли из системы")
      end

      # POST /api/v1/auth/register-user
      #
      # Публичная регистрация B2C-покупателя В КОНТЕКСТЕ АГЕНТСТВА.
      #
      # Требуется один из параметров:
      # - agency_id  — явный выбор агентства;
      # - property_id — регистрация со страницы объекта (агентство берём из property).
      #
      # Также принимает:
      # - phone, email, password, password_confirmation, country_code
      # - first_name, last_name, middle_name, extra_phones (для Contact в агентстве)
      #
      # Побочные эффекты:
      # - Создаёт Person (по телефону) и User (роль :user).
      # - Создаёт/находит Contact (agency_id + person_id) и заполняет ФИО/e-mail/extra_phones.
      # - Создаёт/находит Customer с service_type: :buy в этом агентстве.
      # - Выдаёт JWT, куда кладёт этот agency_id.
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

      # POST /api/v1/auth/register-agent
      #
      # Регистрация B2B пользователя (agent_admin); агентство будет создано отдельно.
      def register_agent_admin
        create_agent_admin
      end

      private

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

      # Разрешённые параметры регистрации
      #
      # NB: first_name/last_name/middle_name/extra_phones — пойдут в Contact при B2C-регистрации.
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
    end
  end
end
