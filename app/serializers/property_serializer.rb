class PropertySerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :price, :discount,
             :listing_type, :status, :created_at, :updated_at, :is_active,
             :characteristics

  belongs_to :category, serializer: PropertyCategorySerializer
  belongs_to :agent, serializer: AgentCompactSerializer
  belongs_to :agency, serializer: AgencyCompactSerializer
  has_one :property_location, serializer: PropertyLocationSerializer

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
