# frozen_string_literal: true

# Сериализатор для модели PropertyComment
# Возвращает информацию о комментарии для отображения нак фронтенде
class PropertyCommentSerializer < ActiveModel::Serializer
  attributes :id, :body, :edited, :edited_at, :edit_count,
             :created_at, :updated_at, :is_deleted,
             :deleted_at, :user

  # Вложенная информация об авторе комментария
  def user
    return nil if object.user.nil?

    {
      id: object.user.id,
      full_name: "#{object.user.last_name} #{object.user.first_name}".strip,
      role: object.user.role
    }
  end
end
