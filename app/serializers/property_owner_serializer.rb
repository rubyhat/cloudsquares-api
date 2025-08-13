# frozen_string_literal: true

# Сериализатор владельца объекта недвижимости.
# Источники данных:
# - ФИО → object.contact.*
# - телефон → object.person.normalized_phone
# - email → object.contact.email
#
# Также отдаём служебные поля и ссылки на связанные сущности.
class PropertyOwnerSerializer < ActiveModel::Serializer
  attributes :id,
             :first_name,
             :last_name,
             :middle_name,
             :phone,
             :email,
             :notes,
             :role,
             :is_deleted,
             :deleted_at,
             :created_at,
             :updated_at

  # Полезные идентификаторы для фронта:
  attributes :contact_id, :person_id, :property_id

  belongs_to :user, serializer: PropertyOwnerUserSerializer, if: -> { object.user.present? }

  # Для совместимости с текущим UI: массив "properties" (сейчас один объект).
  has_many :properties, serializer: PropertyOwnerPropertySerializer

  # ФИО из Contact
  def first_name = object.contact&.first_name
  def last_name  = object.contact&.last_name
  def middle_name = object.contact&.middle_name

  # Телефон из Person
  def phone
    object.person&.normalized_phone
  end

  # Email из Contact
  def email
    object.contact&.email
  end

  def contact_id = object.contact_id
  def person_id  = object.contact&.person_id
  def property_id = object.property_id

  # Т.к. модель связана с одним Property, возвращаем массив из одного элемента.
  def properties
    Array(object.property).compact
  end
end
