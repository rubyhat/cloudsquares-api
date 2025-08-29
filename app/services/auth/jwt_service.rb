# frozen_string_literal: true

module Auth
  class JwtService
    class << self
      # Генерация пары токенов.
      #
      # @param user [User]
      # @param agency_id [String, nil] — опциональный агентский контекст,
      #   который будет помещён в access payload. Если nil, используем user.default_agency&.id.
      # @return [Hash] { access_token:, refresh_token:, iat: }
      def generate_tokens(user, agency_id: nil)
        now = Time.zone.now
        iat = now.to_i

        # Определяем агентство для токена:
        token_agency_id = agency_id || (user.respond_to?(:default_agency) ? user.default_agency&.id : nil)

        access_payload = {
          sub:        user.id,
          exp:        (now + JwtConfig.access_token_ttl).to_i,
          iat:        iat,
          type:       "access",
          role:       user.role,
          phone:      user.person&.normalized_phone,
          first_name: display_first_name_for(user, agency_id: token_agency_id),
          agency_id:  token_agency_id
        }

        refresh_payload = {
          sub:  user.id,
          exp:  (now + JwtConfig.refresh_token_ttl).to_i,
          iat:  iat,
          type: "refresh"
        }

        {
          access_token:  JWT.encode(access_payload, JwtConfig.secret_key, "HS256"),
          refresh_token: JWT.encode(refresh_payload, JwtConfig.secret_key, "HS256"),
          iat:           iat
        }
      end

      def decode(token)
        decoded = JWT.decode(token, JwtConfig.secret_key, true, algorithm: "HS256")
        decoded.first.with_indifferent_access
      rescue JWT::DecodeError
        nil
      end

      def decode_and_verify(token)
        JWT.decode(token, JwtConfig.secret_key, true, { algorithm: "HS256" }).first.with_indifferent_access
      rescue JWT::DecodeError, JWT::ExpiredSignature
        nil
      end

      private

      # Имя для payload: ищем Contact пользователя в заданном агентстве, иначе в дефолтном.
      # Если не нашли — пробуем профиль (для админов).
      def display_first_name_for(user, agency_id:)
        if user.person_id
          target_agency_id = agency_id || user.default_agency&.id
          if target_agency_id
            contact = Contact.find_by(agency_id: target_agency_id, person_id: user.person_id)
            return contact.first_name if contact&.first_name.present?
          end
        end

        return user.profile.first_name if user.profile&.first_name.present?

        user_name(user)
      rescue StandardError
        user_name(user)
      end

      def user_name(user)
        user.respond_to?(:name) ? user.name : "#{user.role}_#{user.id.to_s.first(6)}"
      end
    end
  end
end
