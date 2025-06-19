class CreateProperties < ActiveRecord::Migration[8.0]
  def change
    create_table :properties, id: :uuid do |t|
      t.string :title, null: false
      t.text :description
      t.decimal :price, precision: 12, scale: 2, null: false
      t.decimal :discount, default: 0
      t.integer :listing_type, null: false
      t.integer :status, null: false, default: 0

      t.uuid :category_id, null: false
      t.uuid :agent_id, null: false
      t.uuid :agency_id, null: false

      t.timestamps
    end

    add_index :properties, :agency_id
    add_index :properties, :category_id
    add_index :properties, :agent_id
  end
end
