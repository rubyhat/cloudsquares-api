class CreatePropertyCharacteristics < ActiveRecord::Migration[8.0]
  def change
    create_table :property_characteristics, id: :uuid do |t|
      t.references :agency, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.string :unit
      t.string :field_type, null: false
      t.boolean :is_active, null: false, default: true
      t.integer :position

      t.timestamps
    end

    add_index :property_characteristics, [ :agency_id, :title ], unique: true
  end
end
