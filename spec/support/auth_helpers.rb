module AuthHelpers
  def auth_headers(user)
    tokens = Auth::JwtService.generate_tokens(user)
    { "Authorization" => "Bearer #{tokens[:access_token]}" }
  end
end
