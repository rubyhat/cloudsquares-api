# frozen_string_literal: true

# Сериализатор для фото недвижимости.
# Возвращает все доступные версии изображения и ключевые метаданные.
class PropertyPhotoSerializer < ActiveModel::Serializer
  attributes :id, :file_url, :file_preview_url, :file_retina_url,
             :is_main, :position, :access, :created_at
end
