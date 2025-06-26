class PropertyPolicy < ApplicationPolicy
  # Может ли пользователь просматривать список объектов недвижимости?
  def index?
    true
  end

  def show?
    # TODO: надо подумать, будем ли отдавать на просмотр удаленные объекты(отображать как "объявление в архиве") и другие статусы, кроме active ?
    record.is_active? || manage?
  end

  def create?
    manage?
  end

  def update?
    manage_own_agency?
  end

  def destroy?
    admin? || admin_manager? || (agent_admin? && same_agency?)
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
