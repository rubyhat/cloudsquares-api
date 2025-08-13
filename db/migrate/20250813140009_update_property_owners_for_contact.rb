# frozen_string_literal: true

# PropertyOwner теперь ссылается на contact_id (без хранения ФИО/телефона/e-mail).
class UpdatePropertyOwnersForContact < ActiveRecord::Migration[8.0]
  def change
    add_reference :property_owners, :contact, type: :uuid, null: false, index: true
    add_foreign_key :property_owners, :contacts

    remove_column :property_owners, :first_name, :string, if_exists: true
    remove_column :property_owners, :last_name,  :string, if_exists: true
    remove_column :property_owners, :middle_name, :string, if_exists: true
    remove_column :property_owners, :phone, :string, if_exists: true
    remove_column :property_owners, :email, :string, if_exists: true
  end
end
