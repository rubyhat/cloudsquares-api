# frozen_string_literal: true

# Модель Country представляет поддерживаемые страны в системе.
# Используется при регистрации пользователей и создании агентств.
#
# @!attribute [rw] title
#   @return [String] Полное название страны, например "Казахстан"
# @!attribute [rw] code
#   @return [String] ISO Alpha-2 код страны, например "KZ"
# @!attribute [rw] phone_prefixes
#   @return [Array<String>] Префиксы сотовых телефонов (может быть несколько)
# @!attribute [rw] is_active
#   @return [Boolean] Активна ли страна
# @!attribute [rw] locale
#   @return [String] Язык по умолчанию ("ru", "kk")
# @!attribute [rw] timezone
#   @return [String] Таймзона (например, "Asia/Almaty")
# @!attribute [rw] position
#   @return [Integer] Позиция для сортировки в списках
# @!attribute [rw] default_currency
#   @return [String] Валюта страны (например, "KZT")

class Country < ApplicationRecord
  # Скоуп активных стран
  scope :active, -> { where(is_active: true) }

  validates :title, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true
  validates :phone_prefixes, presence: true
end
