# frozen_string_literal: true

module Api
  module V1
    class AuthController < BaseController
      skip_before_action :authenticate_user!
      before_action :authenticate_user!, only: [:logout]

      # POST /auth/login
      #
      # Аутентифицирует пользователя по номеру телефона и паролю,
      # выдает access_token + refresh_token, сохраняет refresh в Redis.
      def login
        phone = login_params[:phone]&.strip
        password = login_params[:password]

        user = User.find_by(phone: phone)

        if user&.authenticate(password)
          tokens = Auth::JwtService.generate_tokens(user)
          Auth::TokenStorageRedis.save(user_id: user.id, iat: tokens[:iat])

          render json: {
            access_token: tokens[:access_token],
            refresh_token: tokens[:refresh_token]
          }, status: :ok
        else
          render_error(
            key: "auth.invalid_credentials",
            message: "Неверный логин или пароль",
            status: :unauthorized,
            code: 401
          )
        end
      end

      # POST /auth/refresh
      #
      # Проверяет refresh_token, если валиден — выдает новую пару токенов.
      def refresh
        payload = Auth::JwtService.decode_and_verify(params[:refresh_token])

        if payload.present? && payload["type"] == "refresh"
          user = User.find_by(id: payload["sub"])

          if user && Auth::TokenStorageRedis.valid?(user_id: user.id, iat: payload["iat"])
            tokens = Auth::JwtService.generate_tokens(user)
            Auth::TokenStorageRedis.save(user_id: user.id, iat: tokens[:iat])

            render json: {
              access_token: tokens[:access_token],
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

      # POST /auth/logout
      #
      # Удаляет refresh_token пользователя из Redis.
      def logout
        token = request.headers["Authorization"]&.split&.last
        payload = Auth::JwtService.decode(token)

        if payload && payload["sub"]
          Auth::TokenStorageRedis.clear(user_id: payload["sub"])
        end

        render_success(key: "auth.logout", message: "Вы вышли из системы")
      end

      # POST /auth/register-user
      #
      # Публичная регистрация B2C пользователя
      def register_user
        create_new_user(5)
      end

      # POST /auth/register-agent
      #
      # Регистрирует нового B2B пользователя (agent_admin).
      # Не требует авторизации. Без привязки к агентству.
      def register_agent_admin
        create_new_user(2)
      end

      private

      def create_new_user(role)
        user = User.new(register_user_params)
        user.role = role

        if user.save
          tokens = Auth::JwtService.generate_tokens(user)
          Auth::TokenStorageRedis.save(user_id: user.id, iat: tokens[:iat])

          render json: {
            user: UserSerializer.new(user, scope: user),
            access_token: tokens[:access_token],
            refresh_token: tokens[:refresh_token]
          }, status: :created
        else
          render_validation_errors(user)
        end
      end

      # Разрешённые параметры при регистрации пользователей
      def register_user_params
        params.require(:user).permit(
          :phone, :email, :password, :password_confirmation,
          :first_name, :last_name, :middle_name, :country_code
        )
      end

      def login_params
        params.permit(:phone, :password)
      end
    end
  end
end
