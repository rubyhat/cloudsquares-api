# frozen_string_literal: true

class PropertyCharacteristic < ApplicationRecord
  belongs_to :agency

  has_many :property_category_characteristics, dependent: :destroy
  has_many :property_categories, through: :property_category_characteristics
  # has_many :property_values, dependent: :destroy

  validates :title, presence: true, uniqueness: { scope: :agency_id }
  validates :field_type, presence: true, inclusion: { in: %w[string number boolean select] }

  scope :active, -> { where(is_active: true) }
  scope :publicly_visible, -> { where(is_private: false) }
end
