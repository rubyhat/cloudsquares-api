# frozen_string_literal: true

# Модель заявки на покупку недвижимости, создается через публичную платформу.
class PropertyBuyRequest < ApplicationRecord
  belongs_to :property
  belongs_to :agency
  belongs_to :user, optional: true

  scope :active, -> { where(is_deleted: false) }

  enum :status, {
    pending: 0,
    viewed: 1,
    processed: 2,
    rejected: 3
  }, default: :pending

  validates :phone,
            presence: true,
            format: { with: /\A\d{10,15}\z/, message: "должен быть в формате 71234567890" },
            unless: -> { user.present? }

  validates :first_name, presence: true, unless: -> { user.present? }

  validates :status, inclusion: { in: statuses.keys.map(&:to_s) }
  validates :response_message, length: { maximum: 1000 }, allow_blank: true
  validates :comment, length: { maximum: 1000 }, allow_blank: true

  # Мягкое удаление заявки
  def soft_delete!
    update(is_deleted: true, deleted_at: Time.zone.now)
  end
end
