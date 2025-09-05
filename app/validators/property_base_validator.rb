# frozen_string_literal: true

# Typedoc:
# @class PropertyBaseValidator
# @description
#   Кастомный валидатор для Property. Описывает кросс-проверки и правила,
#   соответствующие пошаговому user flow.
#   На этапе создания требуем минимальный набор (title, price, listing_type, category_id),
#   описание необязательно, адрес/фото/характеристики — необязательны.
#   При переводе в статус :active действуют дополнительные требования:
#     1) должны быть указаны: title, price, category_id, listing_type;
#     2) минимум одно фото;
#     3) адрес: country, city, street.
#
# @param record [Property] Экземпляр Property для валидации
# @return [void]
class PropertyBaseValidator < ActiveModel::Validator
  # Выполняет все проверки валидатора
  #
  # @param record [Property]
  # @return [void]
  def validate(record)
    validate_minimal_create_payload(record)
    validate_discount_vs_price(record)
    validate_activation_requirements(record)
  end

  private

  # Минимальный набор полей для создания (create). Эти же поля будут
  # дополнительно проверены при активации (см. validate_activation_requirements).
  #
  # @param record [Property]
  # @return [void]
  def validate_minimal_create_payload(record)
    %i[title price listing_type category_id agency_id agent_id].each do |attr|
      if record.public_send(attr).blank?
        record.errors.add(attr, :blank, message: "Обязательное поле не заполнено")
      end
    end
  end

  # Скидка не должна превышать цену.
  #
  # @param record [Property]
  # @return [void]
  def validate_discount_vs_price(record)
    return if record.price.blank? || record.discount.blank?

    if record.discount.to_d > record.price.to_d
      record.errors.add(:discount, :less_than_or_equal_to, message: "Скидка не может превышать цену")
    end
  end

  # Жёсткие требования к переводу в статус :active.
  #
  # @param record [Property]
  # @return [void]
  def validate_activation_requirements(record)
    return unless record.status.to_s == "active"

    # 1) Базовые поля должны быть указаны
    %i[title price listing_type category_id].each do |attr|
      if record.public_send(attr).blank?
        record.errors.add(attr, :blank, message: "Поле обязательно для статуса 'active'")
      end
    end

    # 2) Должно быть как минимум одно фото
    if record.property_photos.none?
      record.errors.add(:property_photos, :too_few, message: "Добавьте минимум одно фото для статуса 'active'")
    end

    # 3) Геолокация: country, city, street
    loc = record.property_location
    if loc.blank?
      record.errors.add(:property_location, :blank, message: "Укажите адрес (страна, город, улица) для статуса 'active'")
      return
    end

    %i[country city street].each do |attr|
      if loc.public_send(attr).blank?
        # Ошибку кладём в дочернюю модель, чтобы она отобразилась в details.property_location
        loc.errors.add(attr, :blank, message: "Обязательное поле для статуса 'active'")
      end
    end
  end
end
