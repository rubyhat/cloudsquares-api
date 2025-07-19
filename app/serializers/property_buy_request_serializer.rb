# frozen_string_literal: true

class PropertyBuyRequestSerializer < ActiveModel::Serializer
  attributes :id,
             :first_name, :last_name, :phone, :comment,
             :status, :response_message,
             :is_deleted, :deleted_at,
             :created_at, :updated_at, :property_id, :customer_id

  belongs_to :user, serializer: PropertyOwnerUserSerializer, if: -> { object.user.present? }
end
