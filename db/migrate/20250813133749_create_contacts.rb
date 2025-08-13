# frozen_string_literal: true

# Создаёт карточку контакта в рамках агентства:
# - принадлежит agency и person;
# - ФИО/эл.почта/extra_phones/заметки — агентские данные;
# - уникальность пары (agency_id, person_id).
class CreateContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :contacts, id: :uuid do |t|
      t.uuid    :agency_id, null: false
      t.uuid    :person_id, null: false
      t.string  :first_name, null: false
      t.string  :last_name
      t.string  :middle_name
      t.string  :email
      t.string  :extra_phones, array: true, null: false, default: []
      t.text    :notes
      t.boolean :is_deleted, null: false, default: false
      t.datetime :deleted_at
      t.timestamps
    end

    add_foreign_key :contacts, :agencies
    add_foreign_key :contacts, :people
    add_index :contacts, :agency_id
    add_index :contacts, :person_id
    add_index :contacts, [:agency_id, :person_id], unique: true, name: "index_contacts_on_agency_and_person"
    # при желании — защита от дублей email в рамках агентства:
    # add_index :contacts, "lower(email)", where: "email IS NOT NULL", unique: true, name: "index_contacts_on_agency_and_lower_email"
  end
end
