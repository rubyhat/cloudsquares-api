# frozen_string_literal: true

# PhoneNormalizer — единая точка нормализации телефонных номеров.
# Приводит телефон к "цифры‑только" (например, '+7 701 123-45-67' -> '77011234567').
# При необходимости можно добавить сложные правила (валидные префиксы стран и т.д.).
module PhoneNormalizer
  module_function

  # @param raw [String, nil] сырой телефон из формы
  # @return [String] цифры без разделителей; пустая строка если nil/пусто
  def normalize(raw)
    raw.to_s.gsub(/\D+/, "")
  end
end
