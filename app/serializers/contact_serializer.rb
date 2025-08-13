# frozen_string_literal: true

# Сериализатор для Contact: возвращает агентские атрибуты и телефон из Person.
#
# Поля обратной совместимости:
# - phone  — основной телефон (person.normalized_phone)
# - phones — массив: [phone] + extra_phones (нормализованные)
class ContactSerializer < ActiveModel::Serializer
  attributes :id,
             :agency_id,
             :person_id,
             :first_name,
             :last_name,
             :middle_name,
             :email,
             :notes,
             :extra_phones,
             :phone,
             :phones,
             :full_name,
             :is_deleted,
             :deleted_at,
             :created_at,
             :updated_at

  # Основной телефон из Person
  #
  # @return [String, nil]
  def phone
    object.person&.normalized_phone
  end

  # Массив телефонов: основной + дополнительные
  #
  # @return [Array<String>]
  def phones
    main = object.person&.normalized_phone
    extras = Array(object.extra_phones).compact
    ([main].compact + extras).uniq
  end

  # Полное имя
  #
  # @return [String]
  def full_name
    [object.last_name, object.first_name, object.middle_name].compact.join(" ")
  end
end
