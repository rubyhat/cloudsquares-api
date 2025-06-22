# frozen_string_literal: true

# Политика доступа к PropertyOwner — владельцам недвижимости
class PropertyOwnerPolicy < ApplicationPolicy
  def index?
    return true if admin? || admin_manager?

    # Запрос на список комментариев — проверяем доступ к property через Current.agency
    Current.agency.present? && manage?
  end

  def show?
    manage_own_agency? && same_agency?
  end

  def create?
    manage_own_agency?
  end

  def update?
    manage_own_agency? && same_agency?
  end

  def destroy?
    manage_own_agency? && same_agency?
  end

  private

  def same_agency?
    return false unless record.respond_to?(:property)
    Current.agency && record.property.agency_id == Current.agency.id
  end
end
