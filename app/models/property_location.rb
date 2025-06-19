class PropertyLocation < ApplicationRecord
  belongs_to :property

  validates :country, :region, :city, :street, :house_number, presence: true
  validates :is_info_hidden, inclusion: { in: [true, false] }
end
