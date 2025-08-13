# frozen_string_literal: true

# Сериализатор заявки на покупку.
# Обратная совместимость: поля first_name/last_name/phone читаются из Contact/Person.
class PropertyBuyRequestSerializer < ActiveModel::Serializer
  attributes :id,
             :first_name, :last_name, :phone,
             :comment,
             :status, :response_message,
             :is_deleted, :deleted_at,
             :created_at, :updated_at,
             :property_id, :agency_id, :customer_id,
             :contact_id, :person_id

  # Автор заявки (если он зарегистрирован)
  belongs_to :user, serializer: PropertyOwnerUserSerializer, if: -> { object.user.present? }

  # ФИО из Contact
  def first_name = object.contact&.first_name
  def last_name  = object.contact&.last_name

  # Телефон из Person
  def phone
    object.person&.normalized_phone
  end

  def contact_id = object.contact_id
  def person_id  = object.contact&.person_id
end
