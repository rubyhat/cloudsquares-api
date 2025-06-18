# frozen_string_literal: true

class PropertyCategoryCharacteristicPolicy < ApplicationPolicy
  def create?
    manage?
  end

  def destroy?
    manage?
  end

  private

  def manage?
    user.admin? || user.admin_manager? || user.agent_admin?
  end
end
