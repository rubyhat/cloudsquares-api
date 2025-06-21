# Сервис для проверки превышения лимитов, заданных тарифным планом агентства.
#
# Использование:
#   LimitChecker.exceeded?(:employees, agency) => true/false
#
# Поддерживаемые лимиты:
#   :employees, :properties, :photos, :buy_requests, :sell_requests

class LimitChecker
  SUPPORTED_LIMITS = {
    employees: {
      plan_field: :max_employees,
      counter: ->(agency) { agency.users.count }
    },
    properties: {
      plan_field: :max_properties,
      counter: ->(agency) { agency.properties.count }
    },
    photos: {
      plan_field: :max_photos,
      counter: ->(agency) { 0 } # Пока нет модели, можно заглушку
    },
    buy_requests: {
      plan_field: :max_buy_requests,
      counter: ->(agency) { 0 } # Пока нет модели, можно заглушку
    },
    sell_requests: {
      plan_field: :max_sell_requests,
      counter: ->(agency) { 0 } # Пока нет модели, можно заглушку
    }
  }.freeze

  # Проверяет, превышен ли лимит
  #
  # @param limit_key [Symbol] Ключ лимита, например :employees
  # @param agency [Agency] Агентство, для которого проверяется лимит
  # @return [Boolean]
  def self.exceeded?(limit_key, agency)
    raise ArgumentError, "Unknown limit key: #{limit_key}" unless SUPPORTED_LIMITS.key?(limit_key)
    return false if agency.agency_plan.nil?

    limit_config = SUPPORTED_LIMITS[limit_key]
    max_allowed = agency.agency_plan.send(limit_config[:plan_field])
    current_count = limit_config[:counter].call(agency)

    return false if max_allowed.nil? # бесконечный лимит
    current_count >= max_allowed
  end

  def self.check!(limit_key, agency)
    if exceeded?(limit_key, agency)
      raise Pundit::NotAuthorizedError, "Limit exceeded for #{limit_key}"
    end
  end

end
