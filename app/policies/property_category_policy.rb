# frozen_string_literal: true

class PropertyCategoryPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    manage_own_agency?
  end

  def update?
    manage_own_agency?
  end

  def destroy?
    (admin? || admin_manager?) || (agent_admin? && same_agency?)
  end

  def characteristics?
    manage_own_agency?
  end

  class Scope < Scope
    def resolve
      if admin? || admin_manager?
        scope.all
      else
        scope.where(agency_id: Current.agency&.id)
      end
    end
  end
end
