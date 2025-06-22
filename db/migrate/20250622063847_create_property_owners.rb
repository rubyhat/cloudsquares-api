# frozen_string_literal: true

class CreatePropertyOwners < ActiveRecord::Migration[8.0]
  def change
    create_table :property_owners, id: :uuid do |t|
      t.references :property, null: false, foreign_key: true, type: :uuid
      t.references :user, foreign_key: true, type: :uuid

      t.string :first_name, null: false
      t.string :last_name
      t.string :middle_name
      t.string :phone, null: false
      t.string :email
      t.text :notes
      t.integer :role, default: 0, null: false

      t.boolean :is_deleted, null: false, default: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :property_owners, [:property_id, :is_deleted]
  end
end
