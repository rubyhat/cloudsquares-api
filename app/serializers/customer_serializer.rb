# frozen_string_literal: true

# Сериализатор для модели Customer (клиент агентства недвижимости).
# Используется для отображения в списках и детальном просмотре.
class CustomerSerializer < ActiveModel::Serializer
  attributes :id,
             :first_name,
             :last_name,
             :middle_name,
             :full_name,
             :phones,
             :names,
             :service_type,
             :user_id,
             :property_ids,
             :notes,
             :created_at,
             :updated_at

  # Возвращает полное имя клиента в удобном формате
  #
  # @return [String]
  def full_name
    [object.last_name, object.first_name, object.middle_name].compact.join(" ")
  end
end
