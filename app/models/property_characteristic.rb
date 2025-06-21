# frozen_string_literal: true

class PropertyCharacteristic < ApplicationRecord
  belongs_to :agency

  has_many :property_category_characteristics, dependent: :destroy
  has_many :property_categories, through: :property_category_characteristics
  has_many :options, class_name: "PropertyCharacteristicOption", dependent: :destroy

  accepts_nested_attributes_for :options, allow_destroy: true, reject_if: :all_blank

  validates :title, presence: true, uniqueness: { scope: :agency_id }

  # Типы характеристик:
  # - string: строка (input)
  # - text: длинный текст (textarea)
  # - boolean: да/нет (checkbox)
  # - select: выбор из фиксированных значений (select)
  # - number: число (input type="number")
  validates :field_type, presence: true, inclusion: { in: %w[string text boolean select number] }

  scope :active, -> { where(is_active: true) }
  scope :publicly_visible, -> { where(is_private: false) }
end
