# frozen_string_literal: true

class AgencyPlanSerializer < ActiveModel::Serializer
  attributes :id, :title, :description,
             :max_employees, :max_properties,
             :max_photos, :max_buy_requests,
             :max_sell_requests,
             :is_custom, :is_active, :is_default, :created_at, :updated_at
end
