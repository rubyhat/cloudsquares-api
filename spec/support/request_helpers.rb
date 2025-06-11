module RequestHelpers
  def json_body
    JSON.parse(response.body).with_indifferent_access
  rescue JSON::ParserError
    {}
  end
end
