class AgentCompactSerializer < ActiveModel::Serializer
  attributes :id, :first_name, :last_name, :middle_name, :phone
end