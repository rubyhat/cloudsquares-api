# Модель PropertyCharacteristicValue
# Отвечает за хранение значений характеристик недвижимости (кастомных полей), привязанных к конкретному объекту недвижимости
#
# Связи:
# - Принадлежит объекту недвижимости (Property)
# - Принадлежит характеристике (PropertyCharacteristic)
#
# Пример: "этаж — 5", "площадь — 90 м²"
#
# Валидации:
# - Наличие value
# - Присутствие property и characteristic

class PropertyCharacteristicValue < ApplicationRecord
  belongs_to :property
  belongs_to :property_characteristic

  validates :value, presence: true
end
