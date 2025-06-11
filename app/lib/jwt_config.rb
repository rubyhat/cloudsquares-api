# frozen_string_literal: true

# JwtConfig — обёртка над Rails.application.config.x.jwt
# для удобного и безопасного доступа к JWT-настройкам

class JwtConfig
  class << self
    def secret_key
      config[:secret_key]
    end

    def access_token_ttl
      config[:access_token_ttl]
    end

    def refresh_token_ttl
      config[:refresh_token_ttl]
    end

    private

    def config
      Rails.application.config.x.jwt
    end
  end
end
