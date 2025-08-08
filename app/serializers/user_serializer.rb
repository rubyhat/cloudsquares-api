class UserSerializer < ActiveModel::Serializer
  attributes :id, :phone, :role, :country_code, :is_active, :first_name, :last_name, :middle_name

  attribute :email, if: :show_email?
  attribute :agency, if: :has_agency_role?
  attribute :deleted_at, if: -> { object.is_active == false }

  # TODO: подумать, имеет ли смысл скрывать почту от паблика?
  def show_email?
    current_user = scope || instance_options[:current_user]
    return false unless current_user

    return true if current_user.admin? || current_user.admin_manager?
    return true if current_user.id == object.id

    # Сотрудники одного агентства могут видеть email друг друга
    current_agency_id = current_user.user_agencies.find_by(is_default: true)&.agency_id
    target_agency_id = object.user_agencies.find_by(is_default: true)&.agency_id

    current_agency_id.present? &&
      target_agency_id.present? &&
      current_agency_id == target_agency_id
  end

  def agency
    object.user_agencies.find_by(is_default: true)&.agency&.as_json(only: [:id, :title, :slug, :custom_domain])
  end

  def has_agency_role?
    %w[agent_admin agent_manager agent].include?(object.role)
  end
end
