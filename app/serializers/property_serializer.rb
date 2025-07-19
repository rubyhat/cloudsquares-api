# frozen_string_literal: true

# Сериализатор для объекта недвижимости, включает характеристики и владельцев
class PropertySerializer < ActiveModel::Serializer
  attributes :id, :title, :description,
             :listing_type, :status, :created_at, :updated_at, :is_active,
             :characteristics

  attribute :price do
    object.price.round(2).to_f
  end

  attribute :discount do
    object.discount.round(2).to_f
  end

  belongs_to :category, serializer: PropertyCategorySerializer
  belongs_to :agent, serializer: AgentCompactSerializer
  belongs_to :agency, serializer: AgencyCompactSerializer
  has_one :property_location, serializer: PropertyLocationSerializer
  has_many :property_photos, serializer: PropertyPhotoSerializer

  # Правильное подключение коллекции владельцев через has_many с условием
  has_many :property_owners, serializer: PropertyOwnerSerializer, if: :show_owner_data?

  # Кастомные характеристики объекта недвижимости
  #
  # @return [Array<Hash>]
  def characteristics
    object.property_characteristic_values.includes(:property_characteristic).map do |value_record|
      {
        id: value_record.property_characteristic.id,
        title: value_record.property_characteristic.title,
        field_type: value_record.property_characteristic.field_type,
        value: cast_value(value_record)
      }
    end
  end

  # Возвращает только активных владельцев недвижимости
  #
  # @return [ActiveRecord::Relation]
  def property_owners
    object.property_owners.active
  end

  # Показывать ли данные о владельцах
  #
  # @return [Boolean]
  def show_owner_data?
    return false unless Current.user.present? && Current.agency.present?
    object.agency_id == Current.agency.id
  end

  private

  # Преобразует строковое значение в корректный тип в зависимости от field_type
  #
  # @param value_record [PropertyCharacteristicValue]
  # @return [String, Boolean]
  def cast_value(value_record)
    case value_record.property_characteristic.field_type
    when "boolean"
      ActiveModel::Type::Boolean.new.cast(value_record.value)
    else
      value_record.value
    end
  end
end
