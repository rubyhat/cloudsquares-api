# # frozen_string_literal: true
#
# # Политика доступа к PropertyOwner — владельцам недвижимости
# class PropertyOwnerPolicy < ApplicationPolicy
#   def index?
#     return true if admin? || admin_manager?
#
#     # Запрос на список комментариев — проверяем доступ к property через Current.agency
#     Current.agency.present? && manage?
#   end
#
#   def show?
#     manage_own_agency? && same_agency?
#   end
#
#   def create?
#     manage_own_agency?
#   end
#
#   def update?
#     manage_own_agency? && same_agency?
#   end
#
#   def destroy?
#     manage_own_agency? && same_agency?
#   end
#
#   private
#
#   def same_agency?
#     return false unless record.respond_to?(:property)
#     Current.agency && record.property.agency_id == Current.agency.id
#   end
# end

# frozen_string_literal: true

# Политика доступа к владельцам недвижимости (PropertyOwner).
#
# Правила:
# - index? — сотрудники видят владельцев в рамках объекта своего агентства; админы — тоже.
# - show?/update?/destroy?/create? — только в рамках того же агентства (по property.agency_id).
class PropertyOwnerPolicy < ApplicationPolicy
  # Список владельцев для конкретного объекта
  #
  # @return [Boolean]
  def index?
    platform_admin? || (staff? && Current.agency.present?)
  end

  # Просмотр владельца
  #
  # @return [Boolean]
  def show?
    manage_own_agency? && same_agency?
  end

  # Создание владельца
  #
  # @return [Boolean]
  def create?
    # На create в контроллере record уже построен через @property.property_owners.build,
    # поэтому record.property установлен — можно проверить same_agency?
    manage_own_agency? && same_agency?
  end

  # Обновление владельца
  #
  # @return [Boolean]
  def update?
    manage_own_agency? && same_agency?
  end

  # Мягкое удаление владельца
  #
  # @return [Boolean]
  def destroy?
    manage_own_agency? && same_agency?
  end

  # Scope: владельцы в рамках текущего агентства
  class Scope < Scope
    # @return [ActiveRecord::Relation]
    def resolve
      return scope.none unless Current.agency
      return scope.joins(:property).where(properties: { agency_id: Current.agency.id }) if platform_admin? || staff?

      scope.none
    end
  end

  private

  # Совпадает ли агентство объекта владельца с текущим агентством контекста
  #
  # @return [Boolean]
  def same_agency?
    return false unless record.respond_to?(:property) && record.property
    Current.agency && record.property.agency_id == Current.agency.id
  end
end
