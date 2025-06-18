# app/policies/property_characteristic_policy.rb
# frozen_string_literal: true

class PropertyCharacteristicPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def create?
    manage?
  end

  def update?
    manage?
  end

  def destroy?
    manage?
  end

  def categories?
    manage?
  end

  private

  def manage?
    user.admin? || user.admin_manager? || user.agent_admin?
  end
end
