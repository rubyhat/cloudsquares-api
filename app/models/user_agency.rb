class UserAgency < ApplicationRecord
  # Ассоциации
  belongs_to :user
  belongs_to :agency

  # Возможные статусы связи
  enum :status, {
    active: 0,
    banned: 1,
    invited: 2,
    left: 3
  }, default: 0

  validates :user_id, uniqueness: { scope: :agency_id }
  validates :status, presence: true

  # Обеспечивает, что только одна связь может быть по умолчанию
  validate :only_one_default_per_user, if: :is_default?

  private

  def only_one_default_per_user
    existing_default = UserAgency.where(user_id: user_id, is_default: true)
                                 .where.not(id: id)
    if existing_default.exists?
      errors.add(:is_default, "может быть только одна связь по умолчанию")
    end
  end
end
