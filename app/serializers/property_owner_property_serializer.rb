# frozen_string_literal: true

# Мини-карточка объекта для вложенного вывода в владельце.
# Поля:
# - id
# - title
# - main_photo_url — главное фото, если есть; иначе первое по position/created_at
# - address — структура из PropertyLocation (country, region, city, street, house_number)
class PropertyOwnerPropertySerializer < ActiveModel::Serializer
  attributes :id, :title, :main_photo_url, :address

  # URL главного фото, если выставлено is_main; иначе берём первое по position/created_at
  def main_photo_url
    photo = object.property_photos.find { |p| p.is_main } ||
            object.property_photos.min_by { |p| [p.position || Float::INFINITY, p.created_at || Time.zone.at(0)] }
    photo&.file_url
  end

  # Структурированный адрес из PropertyLocation
  def address
    loc = object.property_location
    return nil unless loc

    {
      country:      loc.country,
      region:       loc.region,
      city:         loc.city,
      street:       loc.street,
      house_number: loc.house_number
    }
  end
end
