# frozen_string_literal: true

module Api
  module V1
    class AuthController < BaseController
      skip_before_action :authenticate_user!, only: [ :login, :refresh ]

      # POST /auth/login
      #
      # Аутентифицирует пользователя по номеру телефона и паролю,
      # выдает access_token + refresh_token, сохраняет refresh в Redis.
      def login
        phone = login_params[:phone]&.strip
        password = login_params[:password]

        user = User.find_by(phone: phone)

        if user&.authenticate(password)
          tokens = JwtService.generate_tokens(user)
          TokenStorageRedis.save(user_id: user.id, iat: tokens[:iat])

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
        payload = JwtService.decode_and_verify(params[:refresh_token])

        if payload.present? && payload["type"] == "refresh"
          user = User.find_by(id: payload["sub"])

          if user && TokenStorageRedis.valid?(user_id: user.id, iat: payload["iat"])
            tokens = JwtService.generate_tokens(user)
            TokenStorageRedis.save(user_id: user.id, iat: tokens[:iat])

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
        payload = JwtService.decode(token)

        if payload && payload["sub"]
          TokenStorageRedis.clear(user_id: payload["sub"])
        end

        head :ok
      end

      private

      def login_params
        params.permit(:phone, :password)
      end
    end
  end
end
