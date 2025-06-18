# frozen_string_literal: true
class PropertyCategory < ApplicationRecord
  belongs_to :agency
  belongs_to :parent, class_name: "PropertyCategory", optional: true
  has_many :children, class_name: "PropertyCategory", foreign_key: :parent_id, dependent: :destroy
  has_many :property_category_characteristics, dependent: :destroy
  has_many :property_characteristics, through: :property_category_characteristics
  # has_many :properties, dependent: :restrict_with_error

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: { scope: :agency_id }
  validates :level, inclusion: { in: [0, 1] }
  validate :validate_max_depth

  scope :active, -> { where(is_active: true) }
  scope :roots, -> { where(parent_id: nil) }

  before_validation :generate_slug, if: -> { slug.blank? && title.present? }
  before_validation :assign_level
  before_destroy :check_dependencies

  private

  def check_dependencies
    if children.exists?
      errors.add(:base, "Нельзя удалить категорию с подкатегориями")
      throw :abort
    end

    # if properties.exists?
    #   errors.add(:base, "Нельзя удалить категорию с объектами недвижимости")
    #   throw :abort
    # end
  end

  def generate_slug
    self.slug = title.parameterize
  end

  def assign_level
    self.level = parent_id.nil? ? 0 : 1
  end

  def validate_max_depth
    if parent&.parent.present?
      errors.add(:parent_id, "допустима вложенность только до одного уровня")
    end
  end
end

