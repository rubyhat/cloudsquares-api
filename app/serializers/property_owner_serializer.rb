# frozen_string_literal: true

# Сериализатор для модели PropertyOwner.
# Отображает данные владельца недвижимости сотрудникам агентства.
class PropertyOwnerSerializer < ActiveModel::Serializer
  attributes :id,
             :first_name,
             :last_name,
             :middle_name,
             :phone,
             :email,
             :notes,
             :role,
             :is_deleted,
             :deleted_at,
             :created_at,
             :updated_at

  # Мини-информация о пользователе, если привязан
  belongs_to :user, serializer: PropertyOwnerUserSerializer, if: -> { object.user.present? }

  # Вложенный массив объектов, связанных с владельцем
  has_many :properties, serializer: PropertyOwnerPropertySerializer

  # Т.к. в текущей модели владелец привязан к одному Property,
  # отдаём массив из одного элемента. В будущем можно заменить на связи многие-ко-многим.
  def properties
    Array(object.property).compact
  end
end
