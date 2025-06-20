class AgencyPolicy < ApplicationPolicy
  def index?
    admin? || admin_manager?
  end

  def show?
    admin? || admin_manager? || same_agency?
  end

  def create?
    agent_admin? || admin? || admin_manager?
  end

  def update?
    admin? || admin_manager? || owner?
  end

  def destroy?
    admin? || admin_manager? || owner?
  end

  def change_plan?
    admin? || admin_manager? || (agent_admin? && same_agency?)
  end

  class Scope < Scope
    def resolve
      if admin? || admin_manager?
        scope.all
      else
        scope.where(id: Current.agency&.id)
      end
    end
  end
end
