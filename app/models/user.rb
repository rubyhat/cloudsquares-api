# frozen_string_literal: true

# Модель пользователя.
# Пользователь 1:1 связан с Person (глобальная личность по телефону).
# Телефона/ФИО в таблице users больше нет — телефон живёт в person.normalized_phone,
# ФИО/прочие агентские данные — в Contact внутри конкретного агентства.
#
# Аутентификация: по паре (телефон -> person -> user) + пароль (has_secure_password).
class User < ApplicationRecord
  # Пароль через bcrypt
  has_secure_password

  # Связи
  belongs_to :person

  has_many :user_agencies, dependent: :restrict_with_error
  has_many :agencies, through: :user_agencies
  has_many :property_comments, dependent: :nullify
  has_many :property_buy_requests, dependent: :nullify

  has_one  :profile, class_name: "UserProfile", dependent: :destroy
  after_create :ensure_profile!

  # Текущие доступные регионы
  VALID_COUNTRY_CODES = %w[RU KZ BY].freeze

  # Роли
  enum :role, {
    admin: 0,
    admin_manager: 1,
    agent_admin: 2,
    agent_manager: 3,
    agent: 4,
    user: 5
  }, default: :user

  # Валидации
  validates :person_id, presence: true
  validates :country_code, inclusion: { in: VALID_COUNTRY_CODES }
  # email в users оставляем опциональным (в планах — email только как контактная инфа)
  validates :email, uniqueness: true, allow_nil: true
  validates :password_digest, presence: true

  validate :validate_password_complexity, if: -> { password.present? }

  # Возвращает агентство по умолчанию
  def default_agency
    user_agencies.find_by(is_default: true)&.agency
  end

  def ensure_profile!
    profile || build_profile(timezone: "UTC", locale: I18n.default_locale.to_s).save!
  end

  private

  # Строгая проверка сложности пароля (минимум 12, верхний/нижний регистр, цифра, спецсимвол)
  def validate_password_complexity
    errors.add(:password, "должен содержать минимум 12 символов") unless password.length >= 12
    errors.add(:password, "должен содержать хотя бы одну заглавную букву A-Z") unless password.match?(/[A-Z]/)
    errors.add(:password, "должен содержать хотя бы одну строчную букву a-z") unless password.match?(/[a-z]/)
    errors.add(:password, "должен содержать хотя бы одну цифру") unless password.match?(/\d/)
    errors.add(:password, "должен содержать хотя бы один специальный символ") unless password.match?(/^.*(?=.*[!*@#$%^&+=_-]).*$/)
  end
end
