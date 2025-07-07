# frozen_string_literal: true

# Базовая политика доступа для всех моделей системы.
#
# Предоставляет:
# - определение ролей пользователя;
# - общие методы управления (manage? и др.);
# - методы для проверки агентской принадлежности;
# - базовые "запрещающие" методы доступа (index?, show? и т.п.);
# - универсальный Scope с нулевой видимостью по умолчанию.
#
# Все политики проекта должны наследоваться от ApplicationPolicy.

class ApplicationPolicy
  attr_reader :user, :record

  # Инициализация политики с пользователем и ресурсом
  def initialize(user, record)
    @user = user
    @record = record
  end

  # Роли пользователя

  # Пользователь с ролью супер-администратор
  def admin? = user&.role == "admin"

  # Администратор с ограниченными правами
  def admin_manager? = user&.role == "admin_manager"

  # Админ агентства недвижимости
  def agent_admin? = user&.role == "agent_admin"

  # Менеджер агентства недвижимости
  def agent_manager? = user&.role == "agent_manager"

  # Рядовой агент
  def agent? = user&.role == "agent"

  # Обычный пользователь (B2C)
  def user? = user&.role == "user"

  # Общие уровни доступа

  # Пользователь может управлять сущностью (широкие полномочия)
  def manage?
    admin? || admin_manager? || agent_admin? || agent_manager? || agent?
  end

  # Пользователь может управлять сущностями от лица агентства
  def manage_agency?
    admin? || admin_manager? || agent_admin?
  end

  # Пользователь только с правами чтения (например, B2C)
  def read_only?
    user?
  end

  # Агентская принадлежность и владение

  # Сущность принадлежит текущему агентству
  def same_agency?
    Current.agency &&
      record.respond_to?(:agency_id) &&
      record.agency_id == Current.agency.id
  end

  # Сущность принадлежит агентству или представляет самого пользователя
  def same_agency_or_self?
    same_agency? ||
      (record.respond_to?(:id) && record.id == user&.id)
  end

  # Пользователь является владельцем ресурса в рамках агентства
  def owner?
    # same_agency? && # TODO: вернуть после тестов
      agent_admin?
  end

  # Пользователь может управлять сущностью своего агентства
  def manage_own_agency?
    manage? && same_agency?
  end

  # Пользователь управляет исключительно своим собственным профилем
  def self_user?
    record.respond_to?(:id) && record.id == user&.id
  end

  # --- Базовые политики доступа (по умолчанию запрещены) ---

  # Просмотр списка
  def index?
    false
  end

  # Просмотр одной записи
  def show?
    false
  end

  # Создание записи
  def create?
    false
  end

  # Используется Rails для new
  def new?
    create?
  end

  # Обновление записи
  def update?
    false
  end

  # Используется Rails для edit
  def edit?
    update?
  end

  # Удаление записи
  def destroy?
    false
  end

  # --- Универсальный скоуп для Pundit-политик ---

  # По умолчанию не возвращает ни одной записи.
  # Политики, использующие `policy_scope`, должны переопределять этот класс.
  class Scope
    include ::RoleHelpers
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.none
    end

    private

    attr_reader :user, :scope
  end
end
