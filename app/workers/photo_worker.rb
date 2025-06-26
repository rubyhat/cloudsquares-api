# frozen_string_literal: true

# PhotoWorker — обрабатывает задачи из очереди :photo_worker, полученные от микросервиса загрузки фото.
# В зависимости от типа сущности (entity_type), создает соответствующую запись с данными о фотографии в БД.
#
# Пример входящего payload из микросервиса:
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
#
# Поддерживаемые типы сущностей:
# - "property" — создаёт PropertyPhoto
#
# TODO: Добавить поддержку других entity_type (например: agency, user и т.д.)

class PhotoWorker
  include Sidekiq::Worker
  sidekiq_options queue: :photo_worker

  ##
  # Выполняет задачу обработки фотографии
  #
  # @param [Hash] payload Входные параметры задачи
  # @return [void]
  #
  def perform(payload)
    # Преобразуем ключи в символы для удобства
    data = payload.deep_symbolize_keys
    entity_type = data[:entity_type]

    # Обработка по типу сущности
    case entity_type
    when "property"
      attach_to_property(data)
    else
      # WARNING: Неподдерживаемый тип сущности. Добавить обработку или проигнорировать.
      Rails.logger.warn("[PhotoWorker] Unknown entity_type: #{entity_type}")
    end
  rescue => e
    # WARNING: Возможность "виснущих" задач, если ошибка повторится многократно
    Rails.logger.error("[PhotoWorker] Error processing photo: #{e.class.name} - #{e.message}")
    raise # повторная попытка будет выполнена Sidekiq
  end

  private

  ##
  # Привязывает фото к объекту недвижимости (Property)
  #
  # @param [Hash] data входные данные задачи
  # @return [void]
  #
  def attach_to_property(data)
    property = Property.find_by(id: data[:entity_id])
    unless property
      # WARNING: Потенциальная потеря данных — задача была поставлена, но объект не найден
      Rails.logger.warn("[PhotoWorker] Property not found: #{data[:entity_id]}")
      return
    end

    photo = PropertyPhoto.new(
      property: property,
      file_url: data[:file_url],
      file_preview_url: data[:file_url], # TODO: В будущем можно добавить генерацию preview и retina-версий
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
      # WARNING: Сохранение не удалось — важно логировать ошибки для отладки
      Rails.logger.error("[PhotoWorker] Failed to save photo: #{photo.errors.full_messages.join(', ')}")
    end
  end
end
