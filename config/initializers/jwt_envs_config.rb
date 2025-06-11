# frozen_string_literal: true

# JWT-токены используют HMAC SHA256 по умолчанию
# Мы задаём ключ и параметры жизни токенов в переменных окружения

Rails.application.config.x.jwt ||= ActiveSupport::OrderedOptions.new
Rails.application.config.x.jwt[:secret_key] = ENV.fetch("JWT_SECRET", "secret_key")
Rails.application.config.x.jwt[:access_token_ttl] = ENV.fetch("ACCESS_TOKEN_TTL", "15").to_i.minutes
Rails.application.config.x.jwt[:refresh_token_ttl] = ENV.fetch("REFRESH_TOKEN_TTL", "7").to_i.days
