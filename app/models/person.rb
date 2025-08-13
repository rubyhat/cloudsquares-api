# frozen_string_literal: true

# Person — глобальная личность. Идентификатор — normalized_phone (строка цифр).
# Связи: 1:1 User; 1:N Contacts (в разных агентствах).
class Person < ApplicationRecord
  has_one  :user, dependent: :restrict_with_error
  has_many :contacts, dependent: :restrict_with_error

  validates :normalized_phone,
            presence: true,
            uniqueness: true,
            format: { with: /\A\d+\z/, message: "должен содержать только цифры" }
end
