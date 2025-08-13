# frozen_string_literal: true

# Shared::PhoneNormalizer — единая точка нормализации телефонов (MVP).
#
# Правила:
# - удаляем все нецифровые символы;
# - префикс "00" считаем международным и убираем;
# - если длина = 11 и номер начинается на "8", приводим к "7XXXXXXXXXX" (RU/KZ);
# - если итоговая длина вне 10..15 — считаем невалидным и возвращаем nil.
#
# @example
#   Shared::PhoneNormalizer.normalize("+7 (700) 123-45-67") #=> "77001234567"
#   Shared::PhoneNormalizer.normalize("8 (700) 123-45-67")  #=> "77001234567"
#   Shared::PhoneNormalizer.normalize("00375 29 123 45 67") #=> "375291234567"
module Shared
  module PhoneNormalizer
    module_function

    # Нормализует номер телефона к строке цифр (или nil, если невалиден).
    #
    # @param raw [String, nil] исходная строка номера
    # @return [String, nil] нормализованный номер без знаков, либо nil
    def normalize(raw)
      return nil if raw.nil?

      s = raw.to_s.strip
      s = s.gsub(/\D+/, "")
      return nil if s.empty?

      s = s.sub(/\A00+/, "") # "00..." -> международный префикс
      if s.length == 11 && s.start_with?("8")
        s = "7" + s[1..]    # 8XXXXXXXXXX -> 7XXXXXXXXXX
      end

      (10..15).include?(s.length) ? s : nil
    end
  end
end
