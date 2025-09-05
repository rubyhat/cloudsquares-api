# frozen_string_literal: true

# == Schema Information
#
# Table name: property_locations
#
#  id            :uuid             not null, primary key
#  property_id   :uuid             not null
#  country       :string           not null
#  region        :string           not null
#  city          :string           not null
#  street        :string           not null
#  house_number  :string           not null
#  map_link      :string
#  is_info_hidden: boolean         default(TRUE), not null
#  country_code  :string
#  region_code   :string
#  city_code     :string
#  geo_city_id   :uuid
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
class PropertyLocation < ApplicationRecord
  belongs_to :property

  # Валидации остаются строгими, но применяются только если запись вообще создаётся.
  # На этапе create Property мы НЕ создаём пустую запись адреса.
  validates :country, :region, :city, :street, :house_number, presence: true
  validates :is_info_hidden, inclusion: { in: [true, false] }
end
