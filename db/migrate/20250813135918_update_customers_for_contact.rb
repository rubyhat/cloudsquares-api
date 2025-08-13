# frozen_string_literal: true

# Переводит Customer на Contact.
# - добавляет customers.contact_id: uuid, fk, not null
# - удаляет телефоны/ФИО/денорм-массивы, если они были унаследованы из старых миграций.
class UpdateCustomersForContact < ActiveRecord::Migration[8.0]
  def change
    add_reference :customers, :contact, type: :uuid, null: false, index: true
    add_foreign_key :customers, :contacts

    remove_column :customers, :phones, :string, array: true, if_exists: true
    remove_column :customers, :names, :string, array: true, if_exists: true
    remove_column :customers, :first_name, :string, if_exists: true
    remove_column :customers, :last_name,  :string, if_exists: true
    remove_column :customers, :middle_name, :string, if_exists: true
    remove_column :customers, :property_ids, :uuid, array: true, if_exists: true
  end
end
