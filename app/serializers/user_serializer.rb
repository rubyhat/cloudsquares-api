class UserSerializer < ActiveModel::Serializer
  attributes :id, :phone, :role, :country_code, :is_active, :first_name, :last_name, :middle_name

  attribute :email, if: :show_email?

  def show_email?
    current_user = scope || instance_options[:current_user]
    current_user&.admin? || current_user&.admin_manager? || current_user&.id == object.id
  end
end
