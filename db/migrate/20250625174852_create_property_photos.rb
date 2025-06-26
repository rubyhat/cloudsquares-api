class CreatePropertyPhotos < ActiveRecord::Migration[8.0]
  def change
    create_table :property_photos, id: :uuid do |t|
      t.references :property, null: false, foreign_key: true, type: :uuid

      t.string :file_url, null: false                      # основной файл
      t.string :file_preview_url                           # превью (опционально)
      t.string :file_retina_url                            # retina (опционально)

      t.boolean :is_main, default: false, null: false      # основная фотография
      t.integer :position, null: false, default: 1         # порядок отображения
      t.string :access, null: false, default: 'public'     # тип доступа: public/private

      t.uuid :uploaded_by_id, null: false                  # пользователь, загрузивший фото
      t.uuid :agency_id, null: false                       # агентство-владелец

      t.timestamps
    end

    add_index :property_photos, [:property_id, :is_main], unique: true, where: "is_main = true", name: "index_property_photos_on_property_id_main"
  end
end
