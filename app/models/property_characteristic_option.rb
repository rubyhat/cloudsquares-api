# frozen_string_literal: true

# Варианты выбора для характеристики с типом select
# Пример: характеристика "Этаж", значения: "1", "2", "3"
class PropertyCharacteristicOption < ApplicationRecord
  belongs_to :property_characteristic

  validates :value, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  default_scope { order(:position) }
end
