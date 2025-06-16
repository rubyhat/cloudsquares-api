class AddIsDefaultToAgencyPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :agency_plans, :is_default, :boolean, default: false, null: false
    add_index  :agency_plans, :is_default
  end
end
