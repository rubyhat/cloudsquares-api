# frozen_string_literal: true

# == Model: PropertyOwner
#
# Роль контакта как владельца конкретного объекта недвижимости.
# ДАННЫЕ ВЛАДЕЛЬЦА БОЛЬШЕ НЕ ЖИВУТ В property_owners:
# - ФИО/агентский email — в Contact (agency-scoped),
# - телефон — в Person (глобально по normalized_phone).
#
# Ассоциации:
# - belongs_to :property
# - belongs_to :user, optional: true          — сотрудник/создатель (если используется)
# - belongs_to :contact                        — карточка контакта в рамках агентства
#   (contact → person → normalized_phone)
#
# Валидации:
# - presence: property_id, contact_id, role
# - ограничение на кол-во активных владельцев у Property — не более 5
#
# Скоупы:
# - .active — только не удалённые (is_deleted = false)
#
# Утилиты:
# - #full_name — ФИО из связанного Contact
# - #soft_delete! — мягкое удаление записи владельца
class PropertyOwner < ApplicationRecord
  belongs_to :property
  belongs_to :user,    optional: true
  belongs_to :contact

  # Делегируем доступ к персоне
  delegate :person, to: :contact

  enum :role, {
    primary: 0,    # Основной владелец
    partner: 1,    # Совладелец
    relative: 2,   # Родственник
    other: 3       # Другое
  }, default: :primary

  scope :active, -> { where(is_deleted: false) }

  validates :property_id, presence: true
  validates :contact_id,  presence: true
  validates :role,        presence: true

  validate :max_owners_limit, on: :create

  # Полное имя владельца из Contact
  #
  # @return [String]
  def full_name
    [contact&.last_name, contact&.first_name, contact&.middle_name].compact.join(" ")
  end

  # Мягкое удаление владельца
  #
  # @return [Boolean]
  def soft_delete!
    update(is_deleted: true, deleted_at: Time.zone.now)
  end

  private

  # Бизнес-ограничение: не больше 5 активных владельцев на объект
  #
  # @return [void]
  def max_owners_limit
    if property.property_owners.active.count >= 5
      errors.add(:base, "Максимальное количество владельцев — 5")
    end
  end
end
