# Вложенный сериализатор только для отображения минимальной информации о пользователе,
# если владелец заявки был зарегистрированным пользователем.
class PropertyOwnerUserSerializer < ActiveModel::Serializer
  attributes :id, :first_name, :last_name, :middle_name, :phone, :email, :role
end