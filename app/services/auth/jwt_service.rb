# frozen_string_literal: true

# JwtService — генерация и валидация JWT access и refresh токенов.
#
# Использует алгоритм HS256 с секретным ключом из ENV["JWT_SECRET_KEY"].
# Сроки жизни и другие параметры берутся из конфигурации `Rails.application.config.jwt`.
#
# @example Генерация токенов
#   tokens = Auth::JwtService.generate_tokens(user)
#
# @example Проверка и декодирование токена
#   payload = Auth::JwtService.decode(token)

module Auth
  class JwtService
    class << self
      # Генерирует пару access и refresh токенов
      #
      # @param user [User]
      # @return [Hash] access_token, refresh_token
      def generate_tokens(user)
        now = Time.zone.now
        iat = now.to_i

        # Попытка взять agency_id, если есть default_agency
        agency_id = user.default_agency&.id

        access_payload = {
          sub: user.id,
          exp: (now + JwtConfig.access_token_ttl).to_i,
          iat: iat,
          type: "access",
          role: user.role,
          phone: user.phone,
          first_name: user.first_name || user_name(user),
          agency_id: agency_id
        }

        refresh_payload = {
          sub: user.id,
          exp: (now + JwtConfig.refresh_token_ttl).to_i,
          iat: iat,
          type: "refresh"
        }

        {
          access_token: JWT.encode(access_payload, JwtConfig.secret_key, "HS256"),
          refresh_token: JWT.encode(refresh_payload, JwtConfig.secret_key, "HS256"),
          iat: iat
        }
      end

      # Декодирует токен без проверки срока действия
      #
      # @param token [String]
      # @return [Hash] payload токена
      def decode(token)
        decoded = JWT.decode(token, JwtConfig.secret_key, true, algorithm: "HS256")
        decoded.first.with_indifferent_access
      rescue JWT::DecodeError
        nil
      end

      # Проверяет подпись и срок действия токена
      #
      # @param token [String]
      # @return [Hash, nil] payload токена или nil если недействителен
      def decode_and_verify(token)
        JWT.decode(token, JwtConfig.secret_key, true, { algorithm: "HS256" }).first.with_indifferent_access
      rescue JWT::DecodeError, JWT::ExpiredSignature
        nil
      end

      private
      def user_name(user)
        user.respond_to?(:name) ? user.name : "#{user.role}_#{user.id.to_s.first(6)}"
      end
    end
  end
end
