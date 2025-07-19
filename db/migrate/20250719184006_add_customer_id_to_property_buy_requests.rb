class AddCustomerIdToPropertyBuyRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :property_buy_requests, :customer_id, :uuid
    add_index :property_buy_requests, :customer_id
    add_foreign_key :property_buy_requests, :customers
  end
end
