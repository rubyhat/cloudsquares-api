# frozen_string_literal: true

class PropertyCategoryCharacteristic < ApplicationRecord
  belongs_to :property_category
  belongs_to :property_characteristic

  validates :property_category_id, uniqueness: { scope: :property_characteristic_id }
end
