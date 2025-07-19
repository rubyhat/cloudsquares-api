# app/models/agency.rb

# TODO: добавить автоматическую генерацию slug
class Agency < ApplicationRecord
  # Ассоциации
  has_one :agency_setting, dependent: :destroy
  has_many :property_categories, dependent: :destroy
  has_many :property_characteristics, dependent: :destroy
  has_many :customers, dependent: :destroy

  has_many :property_buy_requests, dependent: :nullify

  after_create :create_agency_setting!
  after_create :seed_default_data!

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :agency_plan, optional: true

  has_many :user_agencies, dependent: :destroy
  has_many :users, through: :user_agencies, dependent: :restrict_with_error

  # TODO: раскомментировать после создания моделей Property, BuyRequest, SellRequest
  has_many :properties, dependent: :restrict_with_error
  # has_many :buy_requests, dependent: :restrict_with_error
  # has_many :sell_requests, dependent: :restrict_with_error

  # В будущем:
  belongs_to :agency_plan
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
    update(is_active: false, deleted_at: Time.zone.now)
  end

  private

  # Создаем настройки агентства для публичной платформы сразу после создания агентства
  def create_agency_setting!
    build_agency_setting(
      site_title: "Недвижимость от #{title}",
      locale: "ru",
      timezone: "Europe/Moscow"
    ).save!
  end

  # Создаем базовые категории и характеристики сразу после создания агентства
  def seed_default_data!
    AgencyTemplateSeeder.new(self).call
  end
end
