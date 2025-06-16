# app/serializers/agency_serializer.rb
class AgencySerializer < ActiveModel::Serializer
  attributes :id, :title, :slug, :custom_domain, :is_blocked, :blocked_at,
             :is_active, :deleted_at, :created_at, :updated_at

  has_one :agency_setting, serializer: AgencySettingSerializer
end
