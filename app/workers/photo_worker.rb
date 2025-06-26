# frozen_string_literal: true

# PhotoWorker — обрабатывает задачи из очереди photo_worker, полученные от микросервиса загрузки фото.
# В зависимости от типа сущности (entity_type), создает соответствующую запись с данными о фотографии.
#
# Пример payload, который приходит из микросервиса:
# {
#   "entity_type": "property",
#   "entity_id": "uuid-сущности",
#   "agency_id": "uuid агентства",
#   "user_id": "uuid пользователя",
#   "file_url": "https://.../image.webp",
#   "is_main": true,
#   "position": 1,
#   "access": "public"
# }

class PhotoWorker
  include Sidekiq::Worker
  sidekiq_options queue: :photo_worker

  def perform(payload)
    # Преобразуем в символы для удобства
    data = payload.deep_symbolize_keys
    entity_type = data[:entity_type]

    # Обрабатываем по типу сущности
    case entity_type
    when "property"
      attach_to_property(data)
    else
      Rails.logger.warn("[PhotoWorker] Unknown entity_type: #{entity_type}")
    end
  rescue => e
    Rails.logger.error("[PhotoWorker] Error processing photo: #{e.message}")
    raise
  end

  private

  # Сохраняет фото в PropertyPhoto
  def attach_to_property(data)
    property = Property.find_by(id: data[:entity_id])
    unless property
      Rails.logger.warn("[PhotoWorker] Property not found: #{data[:entity_id]}")
      return
    end

    photo = PropertyPhoto.new(
      property: property,
      file_url: data[:file_url],
      file_preview_url: data[:file_url],
      file_retina_url: data[:file_url],
      uploaded_by_id: data[:user_id],
      agency_id: data[:agency_id],
      is_main: data[:is_main],
      position: data[:position],
      access: data[:access]
    )

    if photo.save
      Rails.logger.info("[PhotoWorker] Photo saved for property #{property.id}")
    else
      Rails.logger.error("[PhotoWorker] Failed to save photo: #{photo.errors.full_messages.join(', ')}")
    end
  end
end
