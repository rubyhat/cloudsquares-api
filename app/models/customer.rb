# frozen_string_literal: true

# == Schema Information
#
# Table name: customers
#
#  id            :uuid             not null, primary key
#  agency_id     :uuid             not null
#  user_id       :uuid
#  first_name    :string
#  last_name     :string
#  middle_name   :string
#  phones        :string           default([]), not null, is an Array
#  names         :string           default([]), not null, is an Array
#  service_type  :integer          default("buy"), not null
#  property_ids  :uuid             default([]), is an Array
#  notes         :text
#  is_active     :boolean          default(TRUE), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

class Customer < ApplicationRecord
  # Тип услуги, интересующей клиента
  enum :service_type, {
    buy: 0,        # Хочет купить
    sell: 1,       # Хочет продать
    rent_in: 2,    # Хочет снять
    rent_out: 3,   # Хочет сдать
    other: 4       # Другая услуга
  }, default: :other

  # Ассоциации
  belongs_to :agency
  belongs_to :user, optional: true

  # Валидации
  validates :phones, presence: true
  validates :service_type, presence: true

  # Скоуп только активных клиентов
  scope :active, -> { where(is_active: true) }

  # Поиск клиента по одному из номеров телефона (массивное поле phones)
  #
  # @param [String] phone — номер телефона в любом формате
  # @return [ActiveRecord::Relation]
  scope :with_phone, ->(phone) {
    normalized = phone.to_s.gsub(/\D/, "")
    where("phones @> ARRAY[?]::varchar[]", normalized)
  }

  # Утилита: объединить имя клиента
  #
  # @return [String] Полное имя (если есть)
  def full_name
    [last_name, first_name, middle_name].compact.join(" ")
  end
end
