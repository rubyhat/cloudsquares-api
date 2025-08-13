# frozen_string_literal: true

# Общие хелперы ролей для Pundit-политик и их Scope-классов.
# В обоих контекстах доступен метод `user`, поэтому модуль можно смело инклюдить
# и в ApplicationPolicy, и в ApplicationPolicy::Scope.
module RoleHelpers
  # Точечные проверки
  def admin?          = role_is?("admin")
  def admin_manager?  = role_is?("admin_manager")
  def agent_admin?    = role_is?("agent_admin")
  def agent_manager?  = role_is?("agent_manager")
  def agent?          = role_is?("agent")
  def user?           = role_is?("user")

  # Групповые проверки
  # Сотрудник агентства (любой non-B2C персонал + платформенные админы)
  def staff?
    admin? || admin_manager? || agent_admin? || agent_manager? || agent?
  end

  # Платформенные админы
  def platform_admin?
    admin? || admin_manager?
  end

  # Для обратной совместимости: некоторые политики уже ожидают manage?
  alias manage? staff?

  # Универсальная проверка принадлежности роли набору
  # @param roles [Array<String, Symbol>]
  def role_in?(*roles)
    r = (user&.role).to_s
    roles.flatten.map!(&:to_s)
    roles.include?(r)
  end

  private

  def role_is?(value)
    (user&.role).to_s == value.to_s
  end
end
