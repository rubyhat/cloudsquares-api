# frozen_string_literal: true
class CreatePropertyLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :property_locations, id: :uuid do |t|
      t.references :property, null: false, foreign_key: true, type: :uuid

      t.string :country, null: false
      t.string :region, null: false
      t.string :city, null: false
      t.string :street, null: false
      t.string :house_number, null: false
      t.string :map_link

      t.boolean :is_info_hidden, null: false, default: true

      # Подготовка к GeoService
      t.string :country_code
      t.string :region_code
      t.string :city_code
      t.uuid :geo_city_id

      t.timestamps
    end
  end
end
