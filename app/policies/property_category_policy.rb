# frozen_string_literal: true

# Политика доступа для PropertyCategory
class PropertyCategoryPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    manage_categories?
  end

  def update?
    manage_categories?
  end

  def destroy?
    manage_categories? && user.agent_admin? || user.admin? || user.admin_manager?
  end

  private

  def user_in_agency_context?
    user.present? && record.agency_id == Current.agency&.id
  end

  def manage_categories?
    return true if user.admin? || user.admin_manager?
    user_in_agency_context? && (user.agent_admin? || user.agent_manager?)
  end
end
