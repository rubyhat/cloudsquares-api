# app/policies/property_category_characteristic_policy.rb
# frozen_string_literal: true

class PropertyCategoryCharacteristicPolicy < ApplicationPolicy
  def create?
    manage_agency?
  end

  def destroy?
    manage_agency?
  end
end
