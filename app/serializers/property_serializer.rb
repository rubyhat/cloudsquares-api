class PropertySerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :price, :discount,
             :listing_type, :status, :created_at, :updated_at

  belongs_to :category, serializer: PropertyCategorySerializer
  belongs_to :agent, serializer: AgentCompactSerializer
  belongs_to :agency, serializer: AgencyCompactSerializer
  has_one :property_location, serializer: PropertyLocationSerializer
end
