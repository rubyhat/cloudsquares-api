# frozen_string_literal: true

# Сериализатор для Customer с обратной совместимостью по полям ФИО/телефона.
# Источники данных:
# - phone → object.person.normalized_phone
# - first_name/last_name/middle_name → object.contact.*
# - phones (array) → [person.phone] + contact.extra_phones
# - full_name → из Contact
class CustomerSerializer < ActiveModel::Serializer
  attributes :id,
             :service_type,
             :user_id,
             :notes,
             :is_active,
             :created_at,
             :updated_at

  # Обратная совместимость по фронтовым ожиданиям:
  attribute :phone
  attribute :phones
  attribute :first_name
  attribute :last_name
  attribute :middle_name
  attribute :full_name

  # Полезные идентификаторы (могут пригодиться клиенту)
  attribute :contact_id
  attribute :person_id

  # Телефон из Person
  #
  # @return [String, nil]
  def phone
    object.person&.normalized_phone
  end

  # Список телефонов: основной из Person + дополнительные из Contact.extra_phones
  #
  # @return [Array<String>]
  def phones
    main = object.person&.normalized_phone
    extras = Array(object.contact&.extra_phones).compact
    ([main].compact + extras).uniq
  end

  # ФИО из Contact
  def first_name = object.contact&.first_name
  def last_name  = object.contact&.last_name
  def middle_name = object.contact&.middle_name

  # Полное имя
  def full_name
    [last_name, first_name, middle_name].compact.join(" ")
  end

  # Идентификаторы
  def contact_id = object.contact_id
  def person_id  = object.contact&.person_id
end
