class CreatePropertyCharacteristicOptions < ActiveRecord::Migration[8.0]
  def change
    create_table :property_characteristic_options, id: :uuid do |t|
      t.references :property_characteristic, null: false, foreign_key: true, type: :uuid
      t.string :value, null: false
      t.integer :position

      t.timestamps
    end

    add_index :property_characteristic_options, [:property_characteristic_id, :value], unique: true, name: 'index_characteristic_options_uniqueness'
  end
end