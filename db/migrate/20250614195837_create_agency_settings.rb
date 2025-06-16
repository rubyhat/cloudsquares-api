class CreateAgencySettings < ActiveRecord::Migration[8.0]
  def change
    create_table :agency_settings, id: :uuid do |t|
      t.references :agency, type: :uuid, null: false, foreign_key: true, index: { unique: true }

      t.string :logo_url
      t.string :color_scheme
      t.string :locale
      t.string :timezone

      t.jsonb :site_title, default: {}, null: false
      t.jsonb :site_description, default: {}
      t.jsonb :home_page_content, default: {}
      t.jsonb :contacts_page_content, default: {}
      t.jsonb :meta_keywords, default: {}
      t.jsonb :meta_description, default: {}

      t.timestamps
    end
  end
end
