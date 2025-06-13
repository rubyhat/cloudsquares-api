class CreateAgencyPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :agency_plans, id: :uuid do |t|
      t.string  :title, null: false
      t.text    :description
      t.integer :max_employees, null: false, default: 1
      t.integer :max_properties, null: false, default: 10
      t.integer :max_photos, null: false, default: 5
      t.integer :max_buy_requests, null: false, default: 50
      t.integer :max_sell_requests, null: false, default: 10
      t.boolean :is_custom, null: false, default: false
      t.boolean :is_active, null: false, default: true
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :agency_plans, :title, unique: true
  end
end
