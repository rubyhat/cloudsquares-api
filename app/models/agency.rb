# app/models/agency.rb

# TODO: добавить автоматическую генерацию slug
class Agency < ApplicationRecord
  # Ассоциации
  belongs_to :created_by, class_name: "User", optional: true

  has_many :user_agencies, dependent: :destroy
  has_many :users, through: :user_agencies, dependent: :restrict_with_error

  # TODO: раскомментировать после создания моделей Property, BuyRequest, SellRequest
  # has_many :properties, dependent: :restrict_with_error
  # has_many :buy_requests, dependent: :restrict_with_error
  # has_many :sell_requests, dependent: :restrict_with_error

  # В будущем:
  # belongs_to :agency_plan
  # belongs_to :billing_user, class_name: "User", optional: true

  # Валидации
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :custom_domain, uniqueness: true, allow_blank: true

  # Скоупы
  scope :active, -> { where(is_blocked: false) }

  # Метод для определения текущего агентства по домену
  def self.find_by_request_host(host)
    find_by!(custom_domain: host)
  end

  # Мягкое удаление
  def soft_delete!
    update(is_active: false, deleted_at: Time.current)
  end

end
