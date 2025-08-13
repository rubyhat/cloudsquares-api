# frozen_string_literal: true

# == Model: PropertyBuyRequest
#
# Заявка на покупку недвижимости.
# Создаётся с публичной платформы (гостем) или из кабинета (авторизованным пользователем).
#
# ХРАНЕНИЕ ДАННЫХ КЛИЕНТА:
# - Телефон живёт в Person.normalized_phone (глобальный идентификатор личности).
# - ФИО/e-mail/доп. телефоны — в Contact (agency-scoped карточка контакта).
# - В заявке храним contact_id (и, опционально, ссылку на Customer).
#
# ОБЩЕЕ:
# - agency_id дублируем из property.agency_id (быстрый фильтр).
# - user_id — если заявка создана авторизованным пользователем.
# - customer_id — если для этого контакта в агентстве есть/создан Customer.
#
# ВАЖНО: старые поля first_name/last_name/phone в таблице заявки удалены миграцией,
# поэтому любые обращения к ним должны идти через contact/person.
class PropertyBuyRequest < ApplicationRecord
  # Ассоциации
  belongs_to :property
  belongs_to :agency
  belongs_to :user,     optional: true
  belongs_to :customer, optional: true
  belongs_to :contact

  # Доступ к персоне через контакт
  delegate :person, to: :contact

  # Статус жизненного цикла заявки
  enum :status, {
    pending:   0, # создана, ожидает обработки
    viewed:    1, # просмотрена
    processed: 2, # в работе/обработана
    rejected:  3  # отклонена
  }, default: :pending

  # Скоуп активных (не удалённых) заявок
  scope :active, -> { where(is_deleted: false) }

  # Валидации сущностных связей и полей
  validates :property_id, presence: true
  validates :agency_id,   presence: true
  validates :contact_id,  presence: true
  validates :status, inclusion: { in: statuses.keys.map(&:to_s) }
  validates :response_message, length: { maximum: 1000 }, allow_blank: true
  validates :comment,          length: { maximum: 1000 }, allow_blank: true

  # Мягкое удаление
  #
  # @return [Boolean]
  def soft_delete!
    update(is_deleted: true, deleted_at: Time.zone.now)
  end
end
