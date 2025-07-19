class CreateCustomers < ActiveRecord::Migration[8.0]
  def change
    create_table :customers, id: :uuid do |t|
      t.uuid :agency_id, null: false, index: true
      t.uuid :user_id, index: true
      t.string :first_name
      t.string :last_name
      t.string :middle_name
      t.string :phones, array: true, default: [], null: false
      t.string :names, array: true, default: [], null: false
      t.integer :service_type, null: false, default: 0
      t.uuid :property_ids, array: true, default: []
      t.text :notes
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end

    add_foreign_key :customers, :agencies
    add_foreign_key :customers, :users
    add_index :customers, :phones, using: :gin
  end
end
