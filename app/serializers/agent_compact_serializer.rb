# app/serializers/agent_compact_serializer.rb
# frozen_string_literal: true

# TODO: вытаскивание ФИО из контактов повторяется в сериалзиторах, надо вынести в одно место и переиспользовать.
class AgentCompactSerializer < ActiveModel::Serializer
  attributes :id, :first_name, :last_name, :middle_name, :phone

  # Телефон теперь живёт в Person
  def phone
    object.person&.normalized_phone
  end

  # ФИО получаем из Contact в контексте агентства
  def first_name
    contact_in_context&.first_name
  end

  def last_name
    contact_in_context&.last_name
  end

  def middle_name
    contact_in_context&.middle_name
  end

  private

  # Контакт агента в целевом агентстве:
  # 1) приоритет — явно переданный current_agency (идёт через instance_options);
  # 2) fallback — Current.agency (если установлен);
  # 3) fallback — дефолтное агентство самого пользователя (для B2B).
  def contact_in_context
    @contact_in_context ||= begin
                              ctx_agency_id =
                                instance_options[:current_agency]&.id ||
                                Current.agency&.id ||
                                object.user_agencies.find_by(is_default: true)&.agency_id

                              return nil unless ctx_agency_id

                              Contact.find_by(agency_id: ctx_agency_id, person_id: object.person_id)
                            end
  end
end
