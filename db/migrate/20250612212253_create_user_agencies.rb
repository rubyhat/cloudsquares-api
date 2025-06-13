class CreateUserAgencies < ActiveRecord::Migration[7.1]
  def change
    create_table :user_agencies, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :agency, null: false, foreign_key: true, type: :uuid

      t.string :status, null: false, default: "active" # active, banned, invited, left
      t.boolean :is_default, null: false, default: false
      t.datetime :joined_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.datetime :left_at

      t.timestamps
    end

    add_index :user_agencies, [:user_id, :agency_id], unique: true
  end
end
