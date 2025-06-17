# frozen_string_literal: true

# Сериализатор для отображения категории объекта недвижимости
#
# @!attribute id [UUID] ID категории
# @!attribute title [String] Название категории
# @!attribute slug [String] Уникальный слаг
# @!attribute level [Integer] Уровень вложенности (0 = родительская, 1 = подкатегория)
# @!attribute parent_id [UUID, nil] ID родительской категории (если есть)
# @!attribute is_active [Boolean] Включена ли категория
# @!attribute position [Integer] Позиция для сортировки
# @!attribute created_at [DateTime] Дата создания
# @!attribute updated_at [DateTime] Дата обновления
class PropertyCategorySerializer < ActiveModel::Serializer
  attributes :id, :title, :slug, :level, :parent_id, :is_active, :position, :created_at, :updated_at
end
