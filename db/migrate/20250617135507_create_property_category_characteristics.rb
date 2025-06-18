class CreatePropertyCategoryCharacteristics < ActiveRecord::Migration[8.0]
  def change
    create_table :property_category_characteristics, id: :uuid do |t|
      t.references :property_category, null: false, foreign_key: true, type: :uuid
      t.references :property_characteristic, null: false, foreign_key: true, type: :uuid
      t.integer :position

      t.timestamps
    end

    add_index :property_category_characteristics, [:property_category_id, :property_characteristic_id], unique: true, name: 'index_category_characteristics_uniqueness'
  end
end