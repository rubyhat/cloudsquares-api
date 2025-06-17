class CreatePropertyCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :property_categories, id: :uuid do |t|
      t.references :agency, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.string :slug, null: false
      t.integer :position
      t.boolean :is_active, null: false, default: true
      t.uuid :parent_id
      t.integer :level, null: false, default: 0

      t.timestamps
    end

    add_index :property_categories, [:agency_id, :slug], unique: true
    add_index :property_categories, :parent_id
    add_foreign_key :property_categories, :property_categories, column: :parent_id
  end
end
