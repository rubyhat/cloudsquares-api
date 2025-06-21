# app/serializers/property_characteristic_serializer.rb
# frozen_string_literal: true

# Сериализатор для характеристики недвижимости
#
# @!attribute id [UUID] ID характеристики
# @!attribute title [String] Название
# @!attribute unit [String, nil] Единица измерения (м², этаж и т.д.)
# @!attribute field_type [String] Тип поля (string, number, boolean, select)
# @!attribute is_active [Boolean] Активна ли характеристика
# @!attribute is_private [Boolean] Приватна ли характеристика, влияет на видимость на публичной платформе
# @!attribute position [Integer] Позиция сортировки
# @!attribute created_at [DateTime] Дата создания
# @!attribute updated_at [DateTime] Дата обновления
class PropertyCharacteristicSerializer < ActiveModel::Serializer
  attributes :id, :title, :unit, :field_type, :is_active, :is_private, :position, :created_at, :updated_at

  has_many :options, if: -> { object.field_type == "select" }, serializer: PropertyCharacteristicOptionSerializer
end
