class AddAgencyPlanToAgencies < ActiveRecord::Migration[8.0]
  def change
    add_reference :agencies, :agency_plan, foreign_key: true, type: :uuid
  end
end
