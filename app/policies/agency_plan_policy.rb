class AgencyPlanPolicy < ApplicationPolicy
  def show?
    true
  end

  def index?
    true
  end

  def create?
    user.admin? || user.admin_manager?
  end

  def update?
    user.admin? || user.admin_manager?
  end

  def destroy?
    user.admin? || user.admin_manager?
  end
end
