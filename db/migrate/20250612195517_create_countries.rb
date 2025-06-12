# frozen_string_literal: true

class CreateCountries < ActiveRecord::Migration[8.0]
  def change
    create_table :countries, id: :uuid do |t|
      t.string :title, null: false
      t.string :code, null: false
      t.text :phone_prefixes, array: true, default: [], null: false
      t.boolean :is_active, null: false, default: true
      t.string :locale
      t.string :timezone
      t.integer :position
      t.string :default_currency

      t.timestamps
    end

    add_index :countries, :code, unique: true
    add_index :countries, :title, unique: true
  end
end
