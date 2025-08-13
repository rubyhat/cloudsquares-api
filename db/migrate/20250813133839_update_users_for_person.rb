# frozen_string_literal: true

# Переводит User на 1:1 Person.
# - добавляет user.person_id: uuid, fk, unique, not null
# - удаляет устаревшие ФИО/phone из users (если присутствуют в старых миграциях).
class UpdateUsersForPerson < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :person, type: :uuid, null: false, index: { unique: true }
    add_foreign_key :users, :people

    remove_column :users, :phone, :string, if_exists: true
    remove_column :users, :first_name, :string, if_exists: true
    remove_column :users, :last_name, :string, if_exists: true
    remove_column :users, :middle_name, :string, if_exists: true

    # если в старых миграциях был unique-индекс по phone — гарантируем его отсутствие
    remove_index :users, name: "index_users_on_phone", if_exists: true
  end
end
