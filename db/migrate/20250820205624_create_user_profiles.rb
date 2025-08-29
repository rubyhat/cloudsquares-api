# frozen_string_literal: true

class CreateUserProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :user_profiles, id: :uuid do |t|
      t.uuid    :user_id, null: false

      # ФИО — используем для платформенных админов (у B2B/B2C ФИО живёт в Contact)
      t.string  :first_name
      t.string  :last_name
      t.string  :middle_name

      # UI/notifications метаданные
      t.string  :timezone, default: "UTC", null: false
      t.string  :locale,   default: "ru",  null: false

      t.string  :avatar_url

      t.timestamps
    end

    add_index :user_profiles, :user_id, unique: true
    add_foreign_key :user_profiles, :users, column: :user_id
  end
end
