class AgencyPlan < ApplicationRecord
  has_many :agencies

  validates :title, presence: true, uniqueness: true
  validates :max_employees, :max_properties, :max_photos,
            :max_buy_requests, :max_sell_requests,
            numericality: { greater_than_or_equal_to: 0 }
  validate :only_one_default_plan, if: -> { is_default? && is_active? }

  def soft_delete!
    update(is_active: false, deleted_at: Time.current)
  end

  scope :active, -> { where(is_active: true) }

  private
  def only_one_default_plan
    if AgencyPlan.where(is_default: true, is_active: true).where.not(id: id).exists?
      errors.add(:is_default, "может быть только один тариф по умолчанию")
    end
  end
end
