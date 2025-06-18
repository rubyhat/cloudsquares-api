class AgencyTemplateSeeder
  def initialize(agency)
    @agency = agency
  end

  def call
    ActiveRecord::Base.transaction do
      seed_categories
      seed_characteristics
      seed_category_characteristics
    end
  end

  private

  def seed_categories
    @categories ||= {
      flats: @agency.property_categories.create!(title: "Квартиры", slug: "flats", position: 1),
      houses: @agency.property_categories.create!(title: "Частные дома", slug: "houses", position: 2)
    }
  end

  def seed_characteristics
    @characteristics ||= {
      area: create_characteristic("Площадь", "м²", "number", 1),
      rooms: create_characteristic("Количество комнат", nil, "number", 2),
      floor: create_characteristic("Этаж", nil, "number", 3),
      bathroom: create_characteristic("Санузел", nil, "string", 4),
      parking: create_characteristic("Парковка", nil, "boolean", 5)
    }
  end

  def seed_category_characteristics
    flats = @categories[:flats]
    houses = @categories[:houses]

    flats.property_characteristics << @characteristics.values_at(:area, :rooms, :floor)
    houses.property_characteristics << @characteristics.values_at(:area, :bathroom, :parking)
  end

  def create_characteristic(title, unit, field_type, position)
    @agency.property_characteristics.create!(
      title: title,
      unit: unit,
      field_type: field_type,
      position: position
    )
  end
end
