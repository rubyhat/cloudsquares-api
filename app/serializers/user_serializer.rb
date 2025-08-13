# frozen_string_literal: true

# Сериализатор пользователя с обратной совместимостью:
# - phone берём из user.person.normalized_phone
# - ФИО берём из Contact пользователя в его агентстве по умолчанию (если есть),
#   чтобы не ломать фронт, который ожидает поля first_name/last_name/middle_name.
class UserSerializer < ActiveModel::Serializer
  attributes :id, :phone, :role, :country_code, :is_active,
             :first_name, :last_name, :middle_name

  attribute :email, if: :show_email?
  attribute :agency, if: :has_agency_role?
  attribute :deleted_at, if: -> { object.is_active == false }

  def phone
    object.person&.normalized_phone
  end

  def first_name
    contact&.first_name
  end

  def last_name
    contact&.last_name
  end

  def middle_name
    contact&.middle_name
  end

  def agency
    object.user_agencies.find_by(is_default: true)&.agency&.as_json(only: %i[id title slug custom_domain])
  end

  def has_agency_role?
    %w[agent_admin agent_manager agent].include?(object.role)
  end

  # Показ email: админы, сам пользователь, либо сотрудники одного агентства
  def show_email?
    current_user = scope || instance_options[:current_user]
    return false unless current_user

    return true if current_user.admin? || current_user.admin_manager?
    return true if current_user.id == object.id

    cur_agency_id = current_user.user_agencies.find_by(is_default: true)&.agency_id
    target_agency_id = object.user_agencies.find_by(is_default: true)&.agency_id
    cur_agency_id.present? && target_agency_id.present? && cur_agency_id == target_agency_id
  end

  private

  def contact
    # Контакт в агентстве по умолчанию этого пользователя (если есть)
    agency_id = object.user_agencies.find_by(is_default: true)&.agency_id
    return nil unless agency_id

    Contact.find_by(agency_id:, person_id: object.person_id)
  end
end
