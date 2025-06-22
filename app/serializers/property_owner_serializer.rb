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

  belongs_to :user, serializer: PropertyOwnerUserSerializer, if: -> { object.user.present? }
end

