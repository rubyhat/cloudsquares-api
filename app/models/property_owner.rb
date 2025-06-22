# frozen_string_literal: true

class PropertyOwner < ApplicationRecord
  belongs_to :property
  belongs_to :user, optional: true

  enum :role, {
    primary: 0,    # Основной владелец
    partner: 1,    # Совладелец
    relative: 2,   # Родственник
    other: 3       # Другое
  }, default: :primary

  scope :active, -> { where(is_deleted: false) }

  validates :first_name, presence: true
  validates :phone,
            presence: true,
            format: {
              with: /\A\d{10,15}\z/,
              message: "должен быть в формате 71234567890"
            }
  validates :email,
            allow_blank: true,
            format: {
              with: URI::MailTo::EMAIL_REGEXP,
              message: "некорректный формат email"
            }

  validate :max_owners_limit, on: :create

  def full_name
    [last_name, first_name, middle_name].compact.join(" ")
  end

  def soft_delete!
    update(is_deleted: true, deleted_at: Time.zone.now)
  end

  private

  def max_owners_limit
    if property.property_owners.active.count >= 5
      errors.add(:base, "Максимальное количество владельцев — 5")
    end
  end
end
