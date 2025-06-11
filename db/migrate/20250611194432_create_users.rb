class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users, id: :uuid do |t|
      t.string :phone, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :first_name, null: false
      t.string :last_name
      t.string :middle_name
      t.integer :role, null: false, default: 5
      t.string :country_code, null: false, default: "RU"
      t.boolean :is_active, null: false, default: true
      t.datetime :last_sign_in_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :users, :phone, unique: true
    add_index :users, :email, unique: true
  end
end
