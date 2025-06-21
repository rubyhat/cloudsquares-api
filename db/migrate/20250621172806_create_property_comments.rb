# frozen_string_literal: true

class CreatePropertyComments < ActiveRecord::Migration[8.0]
  def change
    create_table :property_comments, id: :uuid do |t|
      t.references :property, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid

      t.text :body, null: false                                 # HTML-тело комментария
      t.boolean :edited, null: false, default: false            # Был ли редактирован
      t.datetime :edited_at                                     # Дата последнего редактирования
      t.integer :edit_count, null: false, default: 0            # Счётчик правок
      t.boolean :is_deleted, null: false, default: false        # Мягкое удаление
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :property_comments, [:property_id, :is_deleted]
  end
end
