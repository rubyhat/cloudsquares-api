class AgencyPlanPolicy < ApplicationPolicy
  def show?
    true
  end

  def index?
    true
  end

  def create?
    admin? || admin_manager?
  end

  def update?
    admin? || admin_manager?
  end

  def destroy?
    admin? || admin_manager?
  end

  # Может ли пользователь использовать данный тарифный план
  def use?
    return false unless record.is_active?
    return true unless record.is_custom?

    admin? || admin_manager?
  end

  # Может ли быть назначен агентству
  def assign_to_agency?
    use?
  end

  class Scope < Scope
    def resolve
      if admin? || admin_manager?
        scope.all
      else
        scope.where(is_custom: false, is_active: true)
      end
    end
  end
end
