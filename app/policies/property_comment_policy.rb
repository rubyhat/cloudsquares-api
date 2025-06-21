# frozen_string_literal: true

# Политика доступа для комментариев к объектам недвижимости
class PropertyCommentPolicy < ApplicationPolicy
  def index?
    return true if admin? || admin_manager?

    # Запрос на список комментариев — проверяем доступ к property через Current.agency
    Current.agency.present? && manage?
  end

  def create?
    manage? && same_property_agency?
  end

  def update?
    manage? && same_property_agency?
  end

  def destroy?
    manage? && same_property_agency?
  end

  private

  def same_property_agency?
    return false unless record.respond_to?(:property) && record.property.present?
    Current.agency && record.property.agency_id == Current.agency.id
  end
end
