# frozen_string_literal: true

# == Schema Information
#
# Table name: properties
#
#  id           :uuid             not null, primary key
#  title        :string           not null
#  description  :text
#  price        :decimal(12, 2)   not null
#  discount     :decimal(, )      default(0.0)
#  listing_type :integer          not null
#  status       :integer          default("pending"), not null
#  is_active    :boolean          default(TRUE), not null
#  deleted_at   :datetime
#  category_id  :uuid             not null
#  agent_id     :uuid             not null
#  agency_id    :uuid             not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class Property < ApplicationRecord
  # Associations
  belongs_to :agency
  belongs_to :agent, class_name: "User"
  belongs_to :category, class_name: "PropertyCategory"

  has_many :property_buy_requests, dependent: :destroy

  has_many :property_owners, dependent: :destroy
  accepts_nested_attributes_for :property_owners, allow_destroy: true

  has_one :property_location, dependent: :destroy
  # Адрес заполняется на следующих шагах; на этапе create он НЕ обязателен.
  accepts_nested_attributes_for :property_location, allow_destroy: true, reject_if: :all_blank

  has_many :property_characteristic_values, dependent: :destroy
  accepts_nested_attributes_for :property_characteristic_values, allow_destroy: true

  has_many :property_comments, dependent: :destroy
  has_many :property_photos, dependent: :destroy

  # Enums
  enum :listing_type, { sale: 0, rent: 1 }, default: :sale
  enum :status, { pending: 0, active: 1, sold: 2, rented: 3, cancelled: 4 }, default: :pending

  # Описание приходит из TipTap — чистим перед валидацией/сохранением
  before_validation :sanitize_description_html

  # Ограничим размер описания, чтобы не хранить мегабайты HTML
  validates :description, length: { maximum: 50_000 }, allow_nil: true

  # Базовые проверки (минимально необходимые поля и числовые ограничения).
  # Детальные и кросс-проверки вынесены в отдельный валидатор.
  validates :title, :price, :listing_type, :status, :agency_id, :category_id, :agent_id, presence: true
  validates :discount, :price, numericality: { greater_than_or_equal_to: 0 }

  # Дополнительные бизнес-проверки и логика шагов создания/активации.
  validates_with PropertyBaseValidator

  # Убираем автосоздание пустых ассоциаций — это ломало транзакцию при create
  # из-за presence-валидаций в PropertyLocation.
  # after_create :create_default_associations

  scope :available, -> { where(is_active: true) }

  # Мягкое удаление
  #
  # @return [Boolean]
  def soft_delete!
    update(is_active: false, deleted_at: Time.zone.now)
  end

  private

  # Пропускает description через безопасный санитайзер.
  #
  # @return [void]
  def sanitize_description_html
    return if description.blank?

    self.description = Shared::RichTextSanitizer.sanitize(description)
  end


  # TODO: Delete after tests:
  # Раньше здесь создавался пустой property_location! со значениями "", что
  # провоцировало RecordInvalid и ROLLBACK. Этот колбэк удалён осознанно —
  # адрес создаётся/редактируется на следующих шагах после минимального create.
  #
  # def create_default_associations
  #   create_property_location!(
  #     country: "", region: "", city: "", street: "",
  #     house_number: "", is_info_hidden: true
  #   ) unless property_location.present?
  #
  #   # create_property_owner!(
  #   #   full_name: "", phone: "", email: "", notes: ""
  #   # ) unless property_owner.present?
  # end
end
