class AgencyPolicy < ApplicationPolicy
  def index?
  end

  def show?
  end

  def create?
    user.agent_admin? || user.admin? || user.admin_manager?
  end

  def update?
    user.admin? || user.admin_manager? || owner?
  end

  def destroy?
    user.admin? || user.admin_manager? || owner?
  end

  private

  def owner?
    user.agent_admin? && record.id == user.agency_id
  end
end
