# frozen_string_literal: true

class PropertyCharacteristicPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def create?
    manage_agency?
  end

  def update?
    manage_agency?
  end

  def destroy?
    manage_agency?
  end

  def categories?
    manage_agency?
  end
end
