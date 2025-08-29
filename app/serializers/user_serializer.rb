# frozen_string_literal: true

class UserSerializer < ActiveModel::Serializer
  attributes :id, :phone, :role, :country_code, :is_active,
             :first_name, :last_name, :middle_name,
             :timezone, :locale, :avatar_url

  attribute :email, if: :show_email?
  attribute :agency, if: :has_agency_role?
  attribute :deleted_at, if: -> { object.is_active == false }

  def phone
    object.person&.normalized_phone
  end

  # --- ФИО ---
  # Если передано instance_options[:prefer_profile_name] — берём имя из профиля
  # (фолбэк на Contact). Иначе наоборот (как раньше).
  def first_name
    if prefer_profile_name?
      object.profile&.first_name || contact_for_context&.first_name
    else
      contact_for_context&.first_name || object.profile&.first_name
    end
  end

  def last_name
    if prefer_profile_name?
      object.profile&.last_name || contact_for_context&.last_name
    else
      contact_for_context&.last_name || object.profile&.last_name
    end
  end

  def middle_name
    if prefer_profile_name?
      object.profile&.middle_name || contact_for_context&.middle_name
    else
      contact_for_context&.middle_name || object.profile&.middle_name
    end
  end

  # --- Профильные поля ---
  def timezone   = object.profile&.timezone
  def locale     = object.profile&.locale
  def avatar_url = object.profile&.avatar_url

  def agency
    object.user_agencies.find_by(is_default: true)&.agency&.as_json(only: %i[id title slug custom_domain])
  end

  def has_agency_role?
    %w[agent_admin agent_manager agent].include?(object.role)
  end

  def show_email?
    current_user = scope || instance_options[:current_user]
    return false unless current_user

    return true if current_user.admin? || current_user.admin_manager?
    return true if current_user.id == object.id

    cur_agency_id    = current_user.user_agencies.find_by(is_default: true)&.agency_id
    target_agency_id = object.user_agencies.find_by(is_default: true)&.agency_id
    cur_agency_id.present? && target_agency_id.present? && cur_agency_id == target_agency_id
  end

  private

  def prefer_profile_name?
    ActiveModel::Type::Boolean.new.cast(instance_options[:prefer_profile_name])
  end

  def contact_for_context
    @contact_for_context ||= begin
                               # 1) явный контекст от вызова: может прийти объектом Agency или UUID/строкой
                               ctx = instance_options[:current_agency]
                               ctx_agency_id =
                                 if ctx.respond_to?(:id)
                                   ctx.id
                                 elsif ctx.is_a?(String)
                                   ctx
                                 else
                                   nil
                                 end

                               # оставляем обратную совместимость на случай, если где-то ещё остался старый ключ
                               ctx_agency_id ||= instance_options[:context_agency_id]

                               # 2) если явно не передали — берём из Current.agency (ставится в BaseController)
                               ctx_agency_id ||= Current.agency&.id

                               if ctx_agency_id
                                 c = Contact.find_by(agency_id: ctx_agency_id, person_id: object.person_id)
                                 return c if c
                               end

                               Contact.where(person_id: object.person_id).order(created_at: :asc).first
                             end
  end
end
