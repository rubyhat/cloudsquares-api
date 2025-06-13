class AgencyPlan < ApplicationRecord
  has_many :agencies

  validates :title, presence: true, uniqueness: true
  validates :max_employees, :max_properties, :max_photos,
            :max_buy_requests, :max_sell_requests,
            numericality: { greater_than_or_equal_to: 0 }

  def soft_delete!
    update(is_active: false, deleted_at: Time.current)
  end

  scope :active, -> { where(is_active: true) }
end
