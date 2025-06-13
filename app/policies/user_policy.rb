# app/policies/user_policy.rb
# frozen_string_literal: true

# Политика доступа для модели User.
# - admin, admin_manager: полный доступ ко всем пользователям
# - agent_admin: доступ только к пользователям своего агентства
# - agent_manager, agent, user: доступ только к самому себе

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

  def me?
    admin? || admin_manager? || same_agency_or_self?
  end

  # Глобальный скоуп для User
  class Scope < Scope
    def resolve
      return scope.all if admin? || admin_manager?

      if agent_admin? && Current.agency
        user_ids = UserAgency.where(agency_id: Current.agency.id).pluck(:user_id)
        return scope.where(id: user_ids)
      end

      scope.where(id: user.id)
    end


    private

    def admin?
      user.role == "admin"
    end

    def admin_manager?
      user.role == "admin_manager"
    end

    def agent_admin?
      user.role == "agent_admin"
    end
  end

  private

  def admin?
    user.role == "admin"
  end

  def admin_manager?
    user.role == "admin_manager"
  end

  def agent_admin?
    user.role == "agent_admin"
  end

  def agent_manager?
    user.role == "agent_manager"
  end

  def agent?
    user.role == "agent"
  end

  def user?
    user.role == "user"
  end

  # Является ли пользователь объектом политики сам собой
  def self_user?
    user.id == record.id
  end

  # Из одного агентства
  def same_agency?
    # user.agency_id.present? && record.agency_id == user.agency_id

    Current.agency && record.agencies.exists?(id: Current.agency.id)
  end

  # Либо сам, либо из того же агентства
  def same_agency_or_self?
    same_agency? || self_user?
  end
end
