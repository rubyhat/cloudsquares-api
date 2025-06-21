class CreatePropertyCharacteristicValues < ActiveRecord::Migration[8.0]
  def change
    create_table :property_characteristic_values, id: :uuid do |t|
      t.references :property, null: false, foreign_key: true, type: :uuid
      t.references :property_characteristic, null: false, foreign_key: true, type: :uuid
      t.string :value, null: false

      t.timestamps
    end

    add_index :property_characteristic_values, [:property_id, :property_characteristic_id], unique: true, name: "index_characteristic_values_uniqueness"
  end
end
