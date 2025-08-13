# frozen_string_literal: true

# == Model: Customer
#
# Customer — роль контакта в рамках агентства (покупатель/продавец/аренда и т.п.).
# Ключевая связь теперь идёт через Contact (agency-scoped), а телефон живёт в Person.
#
# Ассоциации:
# - belongs_to :agency
# - belongs_to :user, optional
# - belongs_to :contact  (ВАЖНО: contact → person → normalized_phone)
#
# Валидации:
# - presence: agency_id, contact_id, service_type
#
# Скоупы/утилиты:
# - .active            — только активные клиенты
# - .with_phone(phone) — поиск по people.normalized_phone через JOIN
# - #full_name         — ФИО из связанного contact
#
# Обратная совместимость:
# - Старые поля phones/names больше НЕ используются в БД.
#   Для выдачи в API сериализатор собирает их из contact/person.
class Customer < ApplicationRecord
  # Тип запрашиваемой услуги
  enum :service_type, {
    buy: 0,        # Хочет купить
    sell: 1,       # Хочет продать
    rent_in: 2,    # Хочет снять
    rent_out: 3,   # Хочет сдать
    other: 4       # Другая услуга
  }, default: :other

  # Ассоциации
  belongs_to :agency
  belongs_to :user, optional: true
  belongs_to :contact

  # Делегации
  delegate :person, to: :contact

  # Валидации
  validates :agency_id, presence: true
  validates :contact_id, presence: true
  validates :service_type, presence: true

  # Скоупы
  scope :active, -> { where(is_active: true) }

  # Поиск клиента по телефону через person.normalized_phone.
  #
  # @param phone [String] телефон в любом формате
  # @return [ActiveRecord::Relation]
  scope :with_phone, lambda { |phone|
    normalized = if defined?(Shared::PhoneNormalizer)
                   Shared::PhoneNormalizer.normalize(phone)
                 else
                   phone.to_s.gsub(/\D/, "")
                 end
    joins(contact: :person).where(people: { normalized_phone: normalized })
  }

  # Полное имя клиента из Contact
  #
  # @return [String]
  def full_name
    [contact&.last_name, contact&.first_name, contact&.middle_name].compact.join(" ")
  end
end
