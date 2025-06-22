# frozen_string_literal: true

class CreatePropertyBuyRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :property_buy_requests, id: :uuid do |t|
      t.references :property, null: false, foreign_key: true, type: :uuid
      t.references :agency, null: false, foreign_key: true, type: :uuid
      t.references :user, foreign_key: true, type: :uuid

      t.string :first_name, null: false
      t.string :last_name
      t.string :phone, null: false
      t.text :comment
      t.text :response_message

      t.integer :status, null: false, default: 0

      t.boolean :is_deleted, null: false, default: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :property_buy_requests, [:property_id, :is_deleted]
    add_index :property_buy_requests, [:agency_id, :status]
  end
end
