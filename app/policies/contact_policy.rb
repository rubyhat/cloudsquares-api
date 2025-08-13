# frozen_string_literal: true

# Политика доступа к контактам (Contact).
#
# Правила:
# - Доступ только сотрудникам агентства (staff?) в рамках Current.agency.
# - Любые операции над record требуют совпадения agency_id.
class ContactPolicy < ApplicationPolicy
  # Просмотр списка контактов
  #
  # @return [Boolean]
  def index?
    staff? && Current.agency.present?
  end

  # Просмотр одного контакта
  #
  # @return [Boolean]
  def show?
    manage_own_agency? && same_agency?
  end

  # Создание контакта
  #
  # @return [Boolean]
  def create?
    manage_own_agency?
  end

  # Обновление контакта
  #
  # @return [Boolean]
  def update?
    manage_own_agency? && same_agency?
  end

  # Мягкое удаление контакта
  #
  # @return [Boolean]
  def destroy?
    manage_own_agency? && same_agency?
  end

  # Скоуп: контакты только текущего агентства, предпочтительно активные
  class Scope < Scope
    # @return [ActiveRecord::Relation]
    def resolve
      return scope.none unless Current.agency
      return scope.where(agency_id: Current.agency.id, is_deleted: false) if staff?

      scope.none
    end
  end

  private

  # Совпадает ли агентство записи с текущим агентством контекста
  #
  # @return [Boolean]
  def same_agency?
    Current.agency && record.agency_id == Current.agency.id
  end
end
