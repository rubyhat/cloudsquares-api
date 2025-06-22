# frozen_string_literal: true

class PropertyBuyRequestPolicy < ApplicationPolicy
  def index?
    return true if admin? || admin_manager?

    # Запрос на список заявок — проверяем доступ к property через Current.agency
    Current.agency.present? && manage?
  end

  def show?
    return true if user == record.user
    manage_own_agency? && same_agency?
  end

  def create?
    true # разрешено всем — валидация по presence
  end

  def update?
    manage_own_agency? && same_agency?
  end


  def destroy?
    manage_own_agency? && same_agency?
  end

  private

  def same_agency?
    Current.agency && record.agency_id == Current.agency.id
  end
end
