# # frozen_string_literal: true
#
# class PropertyBuyRequestPolicy < ApplicationPolicy
#   def index?
#     return true if admin? || admin_manager?
#
#     # Запрос на список заявок — проверяем доступ к property через Current.agency
#     Current.agency.present? && manage?
#   end
#
#   def show?
#     return true if user == record.user
#     manage_own_agency? && same_agency?
#   end
#
#   def create?
#     true # разрешено всем — валидация по presence
#   end
#
#   def update?
#     manage_own_agency? && same_agency?
#   end
#
#
#   def destroy?
#     manage_own_agency? && same_agency?
#   end
#
#   private
#
#   def same_agency?
#     Current.agency && record.agency_id == Current.agency.id
#   end
# end

# frozen_string_literal: true

# Политика доступа к заявкам на покупку (PropertyBuyRequest).
#
# Правила:
# - create? — разрешено всем (в т.ч. гостям) — валидации выполняются в контроллере/модели.
# - index?  — сотрудники видят заявки своего агентства; B2C-пользователь видит только свои заявки
#             в пределах текущего агентства; админы видят всё в рамках Current.agency.
# - show?/update?/destroy? — только в рамках того же агентства; B2C может видеть только свою заявку.
class PropertyBuyRequestPolicy < ApplicationPolicy
  # Список заявок
  #
  # @return [Boolean]
  def index?
    return true if platform_admin?
    return user.present? && Current.agency.present? if user?

    staff? && Current.agency.present?
  end

  # Просмотр заявки
  #
  # @return [Boolean]
  def show?
    return true if user == record.user # B2C владелец своей заявки
    manage_own_agency? && same_agency?
  end

  # Создание заявки
  #
  # @return [Boolean]
  def create?
    true
  end

  # Обновление статуса/ответа менеджера
  #
  # @return [Boolean]
  def update?
    manage_own_agency? && same_agency?
  end

  # Мягкое удаление заявки
  #
  # @return [Boolean]
  def destroy?
    manage_own_agency? && same_agency?
  end

  # Централизованный Scope для index, чтобы не полагаться только на контроллер
  class Scope < Scope
    def resolve
      return scope.none unless Current.agency

      if platform_admin? || staff?
        # Сотрудники агентства — все заявки агентства
        scope.where(agency_id: Current.agency.id)
      elsif user?
        # B2C видит только свои заявки в рамках агентства
        scope.where(agency_id: Current.agency.id, user_id: user.id)
      else
        scope.none
      end
    end
  end

  private

  # Совпадает ли агентство записи с текущим агентством контекста
  #
  # @return [Boolean]
  def same_agency?
    Current.agency && record.agency_id == Current.agency.id
  end
end

