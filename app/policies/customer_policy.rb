# # frozen_string_literal: true
# TODO: DELETE old policy after tests
# # Политика доступа к клиентам агентства недвижимости (Customer).
# # Доступ разрешён только сотрудникам текущего агентства.
# class CustomerPolicy < ApplicationPolicy
#   # Просмотр списка клиентов
#   def index?
#     user_in_own_agency?
#   end
#
#   # Просмотр одного клиента
#   def show?
#     manage_own_agency?
#   end
#
#   # Создание клиента вручную
#   def create?
#     manage_own_agency?
#   end
#
#   # Редактирование клиента
#   def update?
#     manage_own_agency?
#   end
#
#   # Мягкое удаление клиента
#   def destroy?
#     manage_own_agency?
#   end
#
#   # Скоуп: только активные клиенты текущего агентства
#   class Scope < Scope
#     def resolve
#       return scope.none unless Current.agency
#       return scope.where(agency_id: Current.agency.id, is_active: true) if manage?
#
#       scope.none
#     end
#
#     private
#
#     def manage?
#       user&.role.in?(%w[admin admin_manager agent_admin agent_manager agent])
#     end
#   end
#   private
#   # Используется в index?, когда record — это модель, а не объект
#   def user_in_own_agency?
#     user.present? &&
#       %w[admin admin_manager agent_admin agent_manager agent].include?(user.role) &&
#       Current.agency.present?
#   end
# end

# frozen_string_literal: true

# Политика доступа к клиентам агентства недвижимости (Customer).
# Доступ разрешён только сотрудникам текущего агентства.
#
# Инварианты безопасности:
# - Любая операция (кроме пустого index?) требует совпадения record.agency_id с Current.agency.id.
class CustomerPolicy < ApplicationPolicy
  # Просмотр списка клиентов
  #
  # @return [Boolean]
  def index?
    staff? && Current.agency.present?
  end

  # Просмотр одного клиента
  #
  # @return [Boolean]
  def show?
    manage_own_agency? && same_agency?
  end

  # Создание клиента вручную
  #
  # @return [Boolean]
  def create?
    manage_own_agency?
  end

  # Редактирование клиента
  #
  # @return [Boolean]
  def update?
    manage_own_agency? && same_agency?
  end

  # Мягкое удаление клиента
  #
  # @return [Boolean]
  def destroy?
    manage_own_agency? && same_agency?
  end

  # Скоуп: только активные клиенты текущего агентства
  class Scope < Scope
    def resolve
      return scope.none unless Current.agency
      return scope.where(agency_id: Current.agency.id, is_active: true) if staff?

      scope.none
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
