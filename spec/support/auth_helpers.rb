module AuthHelpers
  def auth_headers(user)
    tokens = JwtService.generate_tokens(user)
    { "Authorization" => "Bearer #{tokens[:access_token]}" }
  end
end
