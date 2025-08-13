# frozen_string_literal: true

# Contact — карточка человека в рамках агентства.
# Держит ФИО/e-mail/extra_phones/заметки; основной телефон — у Person.
class Contact < ApplicationRecord
  belongs_to :agency
  belongs_to :person

  has_one  :customer, dependent: :restrict_with_error
  has_many :property_owners, dependent: :restrict_with_error
  has_many :property_buy_requests, dependent: :restrict_with_error

  validates :first_name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :extra_phones, length: { maximum: 10 }

  scope :active, -> { where(is_deleted: false) }
end
