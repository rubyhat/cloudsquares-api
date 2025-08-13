# frozen_string_literal: true

# Мини-информация о пользователе, привязанном к записи владельца.
# Так как у User больше нет собственных ФИО/телефона:
# - phone → user.person.normalized_phone
# - ФИО → пытаемся получить из Contact пользователя в рамках ТЕКУЩЕГО агентства;
#         если не нашли — берём контакт из его агентства по умолчанию.
class PropertyOwnerUserSerializer < ActiveModel::Serializer
  attributes :id, :phone, :email, :role, :first_name, :last_name, :middle_name

  def phone
    object.person&.normalized_phone
  end

  def email
    object.email
  end

  def role
    object.role
  end

  def first_name
    contact_for_user&.first_name
  end

  def last_name
    contact_for_user&.last_name
  end

  def middle_name
    contact_for_user&.middle_name
  end

  private

  # Ищем контакт пользователя в текущем агентстве, иначе в дефолтном агентстве пользователя
  def contact_for_user
    @contact_for_user ||= begin
                            person_id = object.person_id
                            return nil unless person_id

                            # приоритет — Current.agency
                            if Current.respond_to?(:agency) && Current.agency
                              c = Contact.find_by(agency_id: Current.agency.id, person_id:)
                              return c if c
                            end

                            # иначе — агентство по умолчанию самого пользователя
                            default_agency_id = object.user_agencies.find_by(is_default: true)&.agency_id
                            return nil unless default_agency_id

                            Contact.find_by(agency_id: default_agency_id, person_id:)
                          end
  end
end
