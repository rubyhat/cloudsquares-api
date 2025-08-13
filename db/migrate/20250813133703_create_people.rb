# frozen_string_literal: true

# Создаёт глобальную сущность Person:
# - normalized_phone: уникальный идентификатор личности (строка цифр в E.164 без '+').
# - минимальные флаги активности/блокировки.
class CreatePeople < ActiveRecord::Migration[8.0]
  def change
    create_table :people, id: :uuid do |t|
      t.string   :normalized_phone, null: false
      t.boolean  :is_active,        null: false, default: true
      t.datetime :blocked_at
      t.timestamps
    end

    add_index :people, :normalized_phone, unique: true, name: "index_people_on_normalized_phone"
  end
end
