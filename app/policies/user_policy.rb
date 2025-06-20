# app/policies/user_policy.rb
# frozen_string_literal: true

# Политика доступа для модели User.
#
# - admin, admin_manager: имеют полный доступ ко всем пользователям
# - agent_admin: имеет доступ только к пользователям своего агентства
# - agent_manager, agent, user: имеют доступ только к себе (self)
#
# Привязка пользователей к агентству реализована через модель `UserAgency`.
# Контекст текущего агентства определяется через `Current.agency`.

class UserPolicy < ApplicationPolicy
  # Может ли пользователь просматривать список пользователей?
  def index?
    admin? || admin_manager? || agent_admin?
  end

  # Может ли пользователь просматривать конкретного пользователя?
  def show?
    admin? || admin_manager? || same_agency_or_self?
  end

  # Может ли пользователь создать нового пользователя?
  def create?
    return true if admin? || admin_manager?
    agent_admin? && %w[agent_manager agent].include?(record.role)
  end

  # Может ли пользователь обновить пользователя?
  def update?
    admin? || admin_manager? || same_agency_or_self?
  end

  # Может ли пользователь удалить пользователя?
  def destroy?
    admin? || admin_manager? || (agent_admin? && same_agency?)
  end

  # Может ли пользователь получить информацию о себе через /me
  def me?
    admin? || admin_manager? || same_agency_or_self?
  end

  # Скоуп для выборки доступных пользователей
  class Scope < Scope
    # Возвращает:
    # - все записи, если пользователь — админ или менеджер
    # - пользователей своего агентства, если agent_admin
    # - самого себя во всех остальных случаях
    def resolve
      return scope.all if admin? || admin_manager?

      if agent_admin? && Current.agency
        user_ids = UserAgency.where(agency_id: Current.agency.id).pluck(:user_id)
        scope.where(id: user_ids)
      else
        scope.where(id: user.id)
      end
    end
  end
end
