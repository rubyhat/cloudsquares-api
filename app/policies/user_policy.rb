# app/policies/user_policy.rb
# frozen_string_literal: true

# Политика доступа для модели User.
#
# Роли и права:
# - platform_admin? (admin, admin_manager): полный доступ ко всем пользователям.
# - agent_admin: управляет ТОЛЬКО сотрудниками своего агентства (agent_manager, agent);
#                не может трогать admin/admin_manager/agent_admin; не может удалять/менять сам себя.
# - agent_manager, agent, user (B2C): доступ только к себе (self).
#
# Привязка пользователей к агентству — через UserAgency.
# Контекст текущего агентства — Current.agency.
#
# Важно:
# - Проверка «то же агентство» сделана через связь UserAgency.
# - Политика не создаёт привязки к агентству — это обязанность контроллера/сервиса.
class UserPolicy < ApplicationPolicy
  # Может ли пользователь просматривать список пользователей?
  #
  # @return [Boolean]
  def index?
    platform_admin? || (agent_admin? && Current.agency.present?)
  end

  # Может ли пользователь просматривать конкретного пользователя?
  #
  # @return [Boolean]
  def show?
    platform_admin? || same_agency_or_self?
  end

  # Может ли пользователь создать нового пользователя?
  #
  # Разрешено:
  # - platform_admin? — всегда
  # - agent_admin — только роли "agent_manager" или "agent" в рамках своего агентства
  #
  # @return [Boolean]
  def create?
    return true if platform_admin?
    agent_admin? && Current.agency.present? && role_manageable?(record.role)
  end

  # Может ли пользователь обновить пользователя?
  #
  # Разрешено:
  # - platform_admin? — всегда
  # - same_agency_or_self? — если редактируешь себя
  # - agent_admin — роли ниже, в рамках своего агентства
  #
  # @return [Boolean]
  def update?
    return true if platform_admin?
    return true if same_agency_or_self?
    agent_admin? && same_agency? && role_manageable?(record.role)
  end

  # Может ли пользователь удалить пользователя?
  #
  # Разрешено:
  # - platform_admin? — всегда
  # - agent_admin — роли ниже, в рамках своего агентства; нельзя удалять себя
  #
  # @return [Boolean]
  def destroy?
    return true if platform_admin?
    agent_admin? && same_agency? && role_manageable?(record.role) && (user.id != record.id)
  end

  # Может ли пользователь получить информацию о себе через /me
  #
  # @return [Boolean]
  def me?
    platform_admin? || same_agency_or_self?
  end

  # Скоуп для выборки доступных пользователей
  #
  # Возвращает:
  # - всех, если platform_admin?;
  # - пользователей своего агентства, если agent_admin?;
  # - самого себя во всех остальных случаях.
  class Scope < Scope
    def resolve
      return scope.all if platform_admin?

      if agent_admin? && Current.agency
        user_ids = UserAgency.where(agency_id: Current.agency.id).pluck(:user_id)
        scope.where(id: user_ids)
      else
        scope.where(id: user.id)
      end
    end
  end

  private

  # Можно ли управлять пользователем данной роли агентскому админу
  #
  # @param target_role [String, Symbol, nil]
  # @return [Boolean]
  def role_manageable?(target_role)
    %w[agent_manager agent].include?(target_role.to_s)
  end

  # Принадлежит ли record текущему агентству (через UserAgency)
  #
  # @return [Boolean]
  def same_agency?
    return false unless Current.agency
    # record может быть «голой» моделью без предзагрузки — используем exists?
    UserAgency.where(user_id: record.id, agency_id: Current.agency.id).exists?
  end

  # Либо тот же пользователь, либо пользователь из того же агентства
  #
  # @return [Boolean]
  def same_agency_or_self?
    (user.id == record.id) || same_agency?
  end
end
