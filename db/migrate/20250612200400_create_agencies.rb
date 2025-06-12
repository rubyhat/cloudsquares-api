class CreateAgencies < ActiveRecord::Migration[8.0]
  def change
    create_table :agencies, id: :uuid do |t|
      t.string :title, null: false
      t.string :slug, null: false, index: { unique: true }
      t.string :custom_domain, index: { unique: true }
      t.boolean :is_blocked, default: false, null: false
      t.datetime :blocked_at
      t.boolean :is_active, default: true, null: false
      t.datetime :deleted_at
      t.uuid :created_by_id, index: true, null: false

      t.timestamps
    end

    add_foreign_key :agencies, :users, column: :created_by_id
  end
end
