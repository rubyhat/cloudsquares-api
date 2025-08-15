# frozen_string_literal: true

# Сервис атомарной регистрации B2B-пользователя с одновременным созданием агентства.
#
# Последовательность в одной транзакции:
# 1) Нормализуем телефон -> находим/создаём Person (уникальна по normalized_phone).
#    - Если для этой Person уже существует User, возвращаем ошибку (телефон занят).
# 2) Создаём User с ролью :agent_admin (учётные данные + страна).
# 3) Определяем тарифный план для агентства:
#    - Если передан agency_plan_id — берём его (ActiveRecord::RecordNotFound если не существует/неактивен).
#    - Иначе ищем активный план по умолчанию (is_default && is_active).
# 4) Генерируем slug для агентства (если не передан) по title (транслитерация + parameterize).
#    - Если сгенерированный slug уже занят, добавляем -1, -2, ...
# 5) Создаём Agency (created_by: user, agency_plan: plan).
# 6) Привязываем пользователя к агентству через UserAgency (is_default: true, status: :active).
# 7) Создаём Contact в рамках этого агентства для person с переданными ФИО/e-mail.
#
# Возвращает [user, agency].
#
# Исключения:
# - ActiveRecord::RecordInvalid — при валидационных ошибках моделей.
# - ActiveRecord::RecordNotFound — если agency_plan_id указывает на несуществующий план.
# - ActiveRecord::RecordNotUnique — при гонках за уникальные ключи.
#
# Безопасность/идемпотентность:
# - Уникальные индексы people(normalized_phone), agencies(slug), contacts(agency_id, person_id) защитят от дублей.
# - При повторном запросе с тем же телефоном выбросит ошибку «телефон занят».
#
# @example
#   user, agency = Auth::RegisterAgentWithAgency.new(
#     user_params: { phone: "...", email: "...", password: "...", ... },
#     agency_params: { title: "ИП Иванов", slug: nil, agency_plan_id: nil }
#   ).call
#
module Auth
  class RegisterAgentWithAgency
    # @param user_params [Hash] параметры пользователя (phone/email/password/password_confirmation/country_code/first_name/last_name/middle_name)
    # @param agency_params [Hash] параметры агентства (title/slug/custom_domain/agency_plan_id)
    def initialize(user_params:, agency_params:)
      @user_params   = user_params.to_h.deep_symbolize_keys
      @agency_params = agency_params.to_h.deep_symbolize_keys
    end

    # Выполняет регистрацию в одной транзакции.
    #
    # @return [Array(User, Agency)]
    def call
      validate_presence!

      ActiveRecord::Base.transaction do
        person = upsert_person!
        user   = create_user!(person)
        plan   = resolve_agency_plan!
        agency = create_agency!(user: user, plan: plan)
        link_user_to_agency!(user: user, agency: agency)
        create_contact!(agency: agency, person: person, user_email: user.email)
        [user, agency]
      end
    end

    private

    attr_reader :user_params, :agency_params

    # Обязательные поля для минимальной регистрации
    def validate_presence!
      %i[phone password password_confirmation country_code].each do |k|
        raise ActiveRecord::RecordInvalid.new(User.new), "Missing #{k}" if user_params[k].blank?
      end
      raise ActiveRecord::RecordInvalid.new(Agency.new), "Missing agency title" if agency_params[:title].blank?
    end

    # Создаём/находим Person по нормализованному телефону. Если к этой Person уже привязан User — ошибка.
    #
    # @return [Person]
    def upsert_person!
      normalized = ::Shared::PhoneNormalizer.normalize(user_params[:phone].to_s)
      raise ActiveRecord::RecordInvalid.new(User.new), "Invalid phone" if normalized.blank?

      person = Person.find_or_initialize_by(normalized_phone: normalized)
      if person.persisted? && User.exists?(person_id: person.id)
        u = User.new # для передачи в render_validation_errors
        u.errors.add(:base, "Пользователь с таким телефоном уже зарегистрирован")
        raise ActiveRecord::RecordInvalid, u
      end
      person.save! unless person.persisted?
      person
    end

    # Создаёт User с ролью :agent_admin
    #
    # @param person [Person]
    # @return [User]
    def create_user!(person)
      user = User.new(
        person_id:             person.id,
        email:                 user_params[:email],
        password:              user_params[:password],
        password_confirmation: user_params[:password_confirmation],
        role:                  :agent_admin,
        country_code:          user_params[:country_code],
        is_active:             true
      )
      user.save!
      user
    end

    # Возвращает AgencyPlan:
    # - заданный через agency_plan_id, ИЛИ
    # - активный план по умолчанию.
    #
    # @return [AgencyPlan]
    def resolve_agency_plan!
      if agency_params[:agency_plan_id].present?
        plan = AgencyPlan.find(agency_params[:agency_plan_id])
        unless plan.is_a?(AgencyPlan) && plan.is_active?
          ap = AgencyPlan.new
          ap.errors.add(:base, "Указанный тарифный план отключён")
          raise ActiveRecord::RecordInvalid, ap
        end
        plan
      else
        plan = AgencyPlan.find_by(is_default: true, is_active: true)
        unless plan
          ap = AgencyPlan.new
          ap.errors.add(:base, "Не найден активный тариф по умолчанию")
          raise ActiveRecord::RecordInvalid, ap
        end
        plan
      end
    end

    # Создаёт Agency с уникальным slug (если не передан в params).
    #
    # @param user [User]
    # @param plan [AgencyPlan]
    # @return [Agency]
    def create_agency!(user:, plan:)
      title = agency_params[:title].to_s
      slug  = agency_params[:slug].presence || unique_slug_for(title)

      agency = Agency.new(
        title:         title,
        slug:          slug,
        custom_domain: agency_params[:custom_domain],
        created_by:    user,
        agency_plan:   plan
      )
      agency.save!
      agency
    end

    # Привязывает пользователя к агентству и делает его агентством по умолчанию
    #
    # @param user [User]
    # @param agency [Agency]
    # @return [UserAgency]
    def link_user_to_agency!(user:, agency:)
      UserAgency.create!(
        user:        user,
        agency:      agency,
        is_default:  true,
        status:      :active
      )
    end

    # Создаёт Contact в рамках агентства для этой person.
    #
    # @param agency [Agency]
    # @param person [Person]
    # @param user_email [String, nil]
    # @return [Contact]
    def create_contact!(agency:, person:, user_email:)
      Contact.find_or_create_by!(agency_id: agency.id, person_id: person.id) do |c|
        c.first_name   = user_params[:first_name].presence || "—"
        c.last_name    = user_params[:last_name]
        c.middle_name  = user_params[:middle_name]
        c.email        = user_email
        c.extra_phones = []
      end
    end

    # Генерирует уникальный slug на основе title (транслитерация + parameterize).
    # Если занято — добавляет -1, -2, ... пока не найдёт свободный.
    #
    # @param title [String]
    # @return [String]
    def unique_slug_for(title)
      base = ActiveSupport::Inflector.transliterate(title.to_s).parameterize
      base = "agency" if base.blank?

      candidate = base
      suffix = 0
      while Agency.exists?(slug: candidate)
        suffix += 1
        candidate = "#{base}-#{suffix}"
      end
      candidate
    end
  end
end
