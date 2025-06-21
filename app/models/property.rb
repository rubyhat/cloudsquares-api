class Property < ApplicationRecord
  belongs_to :agency
  belongs_to :agent, class_name: "User"
  belongs_to :category, class_name: "PropertyCategory"

  has_one :property_location, dependent: :destroy
  accepts_nested_attributes_for :property_location, allow_destroy: true, reject_if: :all_blank

  has_many :property_characteristic_values, dependent: :destroy
  accepts_nested_attributes_for :property_characteristic_values, allow_destroy: true

  enum :listing_type, { sale: 0, rent: 1 }, default: :sale
  enum :status, { pending: 0, active: 1, sold: 2, rented: 3, cancelled: 4 }, default: :pending

  validates :title, :price, :listing_type, :status, :agency_id, :category_id, :agent_id, presence: true
  validates :discount, :price, numericality: { greater_than_or_equal_to: 0 }

  after_create :create_default_associations

  scope :active, -> { where(is_active: true) }

  def soft_delete!
    update(is_active: false, deleted_at: Time.current)
  end

  private

  def create_default_associations
    create_property_location!(
      country: "", region: "", city: "", street: "",
      house_number: "", is_info_hidden: true
    ) unless property_location.present?

    # create_property_owner!(
    #   full_name: "", phone: "", email: "", notes: ""
    # ) unless property_owner.present?
  end
end
