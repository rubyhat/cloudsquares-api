class PropertyLocationSerializer < ActiveModel::Serializer
  attributes :country, :region, :city, :street, :house_number,
             :map_link, :is_info_hidden, :geo_city_id
end