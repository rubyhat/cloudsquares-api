class AddIsPrivateToPropertyCharacteristics < ActiveRecord::Migration[8.0]
  def change
    add_column :property_characteristics, :is_private, :boolean, null: false, default: false
  end
end