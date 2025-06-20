class PropertyPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    record.active? || manage?
  end

  def create?
    manage?
  end

  def update?
    manage_own_agency?
  end

  def destroy?
    user.admin? || user.admin_manager? || (user.agent_admin? && own_agency?)
  end

  private

  def manage?
    user.admin? || user.admin_manager? || user.agent_admin? || user.agent_manager? || user.agent?
  end

  def own_agency?
    record.agency_id == Current.agency&.id
  end

  def manage_own_agency?
    manage? && own_agency?
  end
end
