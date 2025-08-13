# frozen_string_literal: true

# Заявки на покупку теперь ссылаются на contact_id (без хранения ФИО/телефона).
class UpdatePropertyBuyRequestsForContact < ActiveRecord::Migration[8.0]
  def change
    add_reference :property_buy_requests, :contact, type: :uuid, null: false, index: true
    add_foreign_key :property_buy_requests, :contacts

    remove_column :property_buy_requests, :first_name, :string, if_exists: true
    remove_column :property_buy_requests, :last_name,  :string, if_exists: true
    remove_column :property_buy_requests, :phone,      :string, if_exists: true
  end
end
