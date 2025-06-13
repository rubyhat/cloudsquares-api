# frozen_string_literal: true

# Модель пользователя
# Пользователи могут быть B2B или B2C, принадлежать агентству или быть нецелевыми клиентами.
# Аутентификация осуществляется по номеру телефона и паролю.

class User < ApplicationRecord
  # Поддержка пароля через bcrypt
  has_secure_password

  # Ассоциации
  has_many :user_agencies, dependent: :restrict_with_error
  has_many :agencies, through: :user_agencies

  # Текущие доступные регионы
  VALID_COUNTRY_CODES = %w[RU KZ BY].freeze

  # Перечисление доступных ролей
  enum :role, {
    admin: 0,
    admin_manager: 1,
    agent_admin: 2,
    agent_manager: 3,
    agent: 4,
    user: 5
  }, default: :user

  # Валидации
  validates :phone,
            presence: true,
            uniqueness: true,
            format: {
              with: /\A\d{10,15}\z/,
              message: "должен быть в формате 71234567890"
            }

  validates :country_code, inclusion: { in: VALID_COUNTRY_CODES }
  validates :email, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :password_digest, presence: true
  validate :validate_password_complexity, if: -> { password.present? } # Валидация сложности пароля

  private

  def validate_password_complexity
    unless password.length >= 12
      errors.add(:password, "должен содержать минимум 12 символов")
    end

    unless password.match?(/[A-Z]/)
      errors.add(:password, "должен содержать хотя бы одну заглавную букву A-Z")
    end

    unless password.match?(/[a-z]/)
      errors.add(:password, "должен содержать хотя бы одну строчную букву a-z")
    end

    unless password.match?(/\d/)
      errors.add(:password, "должен содержать хотя бы одну цифру")
    end

    unless password.match?(/^.*(?=.*[!*@#$%^&+=_-]).*$/)
      errors.add(:password, "должен содержать хотя бы один специальный символ")
    end
  end
end
