# puts "🌍 Добавляем страны..."
#
# [
#   {
#     title: "Казахстан",
#     code: "KZ",
#     phone_prefixes: ["+7"],
#     is_active: true,
#     locale: "ru",
#     timezone: "Asia/Almaty",
#     position: 1,
#     default_currency: "KZT"
#   },
#   {
#     title: "Россия",
#     code: "RU",
#     phone_prefixes: ["+7"],
#     is_active: true,
#     locale: "ru",
#     timezone: "Europe/Moscow",
#     position: 2,
#     default_currency: "RUB"
#   },
#   {
#     title: "Беларусь",
#     code: "BY",
#     phone_prefixes: ["+375"],
#     is_active: true,
#     locale: "ru",
#     timezone: "Europe/Minsk",
#     position: 3,
#     default_currency: "BYN"
#   }
# ].each do |attrs|
#   Country.find_or_initialize_by(code: attrs[:code]).tap do |country|
#     country.assign_attributes(attrs)
#     country.save!
#   end
# end
#
# puts "🌍 Создаём тарифные планы..."
#
# AgencyPlan.find_or_create_by!(title: "Пробный") do |plan|
#   plan.description = "Бесплатный тариф с базовыми возможностями"
#   plan.max_employees = 1
#   plan.max_properties = 5
#   plan.max_photos = 5
#   plan.max_buy_requests = 5
#   plan.max_sell_requests = 5
#   plan.is_custom = false
#   plan.is_active = true
#   plan.is_default = true
# end
#
# puts "👑 Создаём пользователей по ролям..."
#
# users = [
#   {
#     phone: "77000000001",
#     email: "admin@cloudsquares.local",
#     password: "UserPassword1@",
#     role: :admin,
#     country_code: "RU",
#     first_name: "John Doe 1"
#   },
#   {
#     phone: "77000000002",
#     email: "admin_manager@cloudsquares.local",
#     password: "UserPassword1@",
#     role: :admin_manager,
#     country_code: "RU",
#     first_name: "John Doe 2"
#   },
#   {
#     phone: "77000000003",
#     email: "agent_admin@cloudsquares.local",
#     password: "UserPassword1@",
#     role: :agent_admin,
#     country_code: "RU",
#     first_name: "John Doe 3"
#   },
#   {
#     phone: "77000000004",
#     email: "agent_manager@cloudsquares.local",
#     password: "UserPassword1@",
#     role: :agent_manager,
#     country_code: "RU",
#     first_name: "John Doe 4"
#   },
#   {
#     phone: "77000000005",
#     email: "agent@cloudsquares.local",
#     password: "UserPassword1@",
#     role: :agent,
#     country_code: "RU",
#     first_name: "John Doe 5"
#   },
#   {
#     phone: "77000000006",
#     email: "user@cloudsquares.local",
#     password: "UserPassword1@",
#     role: :user,
#     country_code: "RU",
#     first_name: "John Doe 6"
#   }
# ]
#
# users.each do |attrs|
#   User.find_or_initialize_by(phone: attrs[:phone]).tap do |user|
#     user.assign_attributes(
#       email: attrs[:email],
#       password: attrs[:password],
#       password_confirmation: attrs[:password],
#       role: attrs[:role],
#       country_code: attrs[:country_code],
#       is_active: true,
#       first_name: attrs[:first_name]
#     )
#     user.save!
#   end
# end
#
# # puts "👑 Создаём Категории внутри агентства..."
# # agency = Agency.first
# #
# # %w[Квартира Дом Коммерческая\ недвижимость Земельный\ участок].each_with_index do |title, i|
# #   PropertyCategory.create!(
# #     agency: agency,
# #     title: title,
# #     slug: title.parameterize,
# #     position: i + 1
# #   )
# # end

# frozen_string_literal: true

# db/seeds.rb — базовые сид-данные для CloudSquares
#
# Что делает:
# 1) Создаёт страны (Country).
# 2) Создаёт тарифный план "Пробный" (AgencyPlan) и гарантирует,
#    что он будет единственным default-планом среди активных.
# 3) Создаёт пользователей всех ролей: admin, admin_manager, agent_admin,
#    agent_manager, agent, user — через Person (по телефону) → User (1:1).
# 4) Создаёт демо-агентство и привязывает к нему агентские роли,
#    создаёт для них Contact внутри агентства.
#
# Важно:
# - В users больше нет телефон/ФИО: телефон хранится в people.normalized_phone,
#   ФИО/агентский email — в contacts.
# - Agency обязана иметь agency_plan → задаём план до save!.
# - Сиды идемпотентные (повторный запуск безопасен).

# ────────────────────────────────────────────────────────────────────────────
# УТИЛИТЫ
# ────────────────────────────────────────────────────────────────────────────

# @param msg [String] сообщение в лог
# @return [void]
def say(msg)
  puts msg
end

# Унифицированная нормализация телефона (цифры без разделителей).
# @param raw [String, nil]
# @return [String] нормализованный номер
def normalize_phone(raw)
  if defined?(PhoneNormalizer)
    ::Shared::PhoneNormalizer.normalize(raw)
  else
    raw.to_s.gsub(/\D+/, "")
  end
end

# Находит или создаёт Person по телефону.
# @param phone [String]
# @return [Person]
def ensure_person!(phone)
  pn = normalize_phone(phone)
  raise ArgumentError, "Empty phone for Person" if pn.blank?
  Person.find_or_create_by!(normalized_phone: pn)
end

# Находит или создаёт User, жёстко связывая его с person (1:1).
# Email необязателен; пароль обязателен (has_secure_password).
# @param person [Person]
# @param email [String, nil]
# @param password [String]
# @param role [String, Symbol]
# @param country_code [String]
# @param is_active [Boolean]
# @return [User]
def ensure_user!(person:, email:, password:, role:, country_code:, is_active: true)
  user = User.find_or_initialize_by(person_id: person.id)
  user.email                 = email
  user.password              = password
  user.password_confirmation = password
  user.role                  = role
  user.country_code          = country_code if user.respond_to?(:country_code=)
  user.is_active             = is_active if user.respond_to?(:is_active=)
  user.save!
  user
end

# Создаёт/возвращает Agency с обязательными created_by и agency_plan.
# План должен быть передан заранее (обычно дефолтный "Пробный").
# @param title [String]
# @param slug [String]
# @param created_by [User]
# @param agency_plan [AgencyPlan]
# @param custom_domain [String, nil]
# @return [Agency]
def ensure_agency!(title:, slug:, created_by:, agency_plan:, custom_domain: nil)
  raise ArgumentError, "created_by user required" unless created_by&.id
  raise ArgumentError, "agency_plan required" unless agency_plan&.id

  agency = Agency.find_or_initialize_by(slug: slug)
  agency.title         = title
  agency.custom_domain = custom_domain if custom_domain.present?
  agency.created_by    = created_by
  agency.agency_plan   = agency_plan   # критично: belongs_to обязательный
  # Флаги — если есть такие атрибуты в схеме
  agency.is_blocked    = false if agency.has_attribute?(:is_blocked)
  agency.is_active     = true  if agency.has_attribute?(:is_active)
  agency.save!
  agency
end

# Создаёт/возвращает связь пользователь↔агентство, помечая дефолт при необходимости.
# @param user [User]
# @param agency [Agency]
# @param is_default [Boolean]
# @param status [Symbol, String] статус связи (если колонка существует)
# @return [UserAgency]
def ensure_user_agency!(user:, agency:, is_default: true, status: :active)
  ua = UserAgency.find_or_initialize_by(user_id: user.id, agency_id: agency.id)
  ua.is_default = is_default if ua.respond_to?(:is_default=)
  ua.status     = status     if ua.respond_to?(:status=)
  ua.joined_at  = Time.zone.now if ua.respond_to?(:joined_at) && ua.joined_at.nil?
  ua.save!
  ua
end

# Создаёт Contact в рамках агентства для person (если такого ещё нет).
# @param agency [Agency]
# @param person [Person]
# @param first_name [String]
# @param last_name [String, nil]
# @param middle_name [String, nil]
# @param email [String, nil] агентский email
# @return [Contact]
def ensure_contact!(agency:, person:, first_name:, last_name: nil, middle_name: nil, email: nil)
  contact = Contact.find_or_initialize_by(agency_id: agency.id, person_id: person.id)
  contact.first_name  = first_name.presence || contact.first_name || "—"
  contact.last_name   = last_name   if last_name.present? || contact.last_name.blank?
  contact.middle_name = middle_name if middle_name.present? || contact.middle_name.blank?
  contact.email       = email       if email.present? || contact.email.blank?
  contact.extra_phones ||= []
  contact.is_deleted  = false if contact.respond_to?(:is_deleted=)
  contact.save!
  contact
end

# ────────────────────────────────────────────────────────────────────────────
# СИД-ДАННЫЕ
# ────────────────────────────────────────────────────────────────────────────

ActiveRecord::Base.transaction do
  # 1) Страны
  say "🌍 Добавляем страны..."

  [
    {
      title: "Казахстан",
      code: "KZ",
      phone_prefixes: ["+7"],
      is_active: true,
      locale: "ru",
      timezone: "Asia/Almaty",
      position: 1,
      default_currency: "KZT"
    },
    {
      title: "Россия",
      code: "RU",
      phone_prefixes: ["+7"],
      is_active: true,
      locale: "ru",
      timezone: "Europe/Moscow",
      position: 2,
      default_currency: "RUB"
    },
    {
      title: "Беларусь",
      code: "BY",
      phone_prefixes: ["+375"],
      is_active: true,
      locale: "ru",
      timezone: "Europe/Minsk",
      position: 3,
      default_currency: "BYN"
    }
  ].each do |attrs|
    country = Country.find_or_initialize_by(code: attrs[:code])
    country.assign_attributes(attrs)
    country.save!
  end

  # 2) Тарифные планы
  say "🧾 Создаём тарифные планы..."

  trial = AgencyPlan.find_or_initialize_by(title: "Пробный")
  trial.description        ||= "Бесплатный тариф с базовыми возможностями"
  trial.max_employees      ||= 1
  trial.max_properties     ||= 5
  trial.max_photos         ||= 5
  trial.max_buy_requests   ||= 5
  trial.max_sell_requests  ||= 5
  trial.is_custom          = false if trial.is_custom.nil?
  trial.is_active          = true  if trial.is_active.nil?

  # Гарантируем, что будет лишь один активный дефолтный план
  has_other_default = AgencyPlan.where(is_default: true, is_active: true).where.not(id: trial.id).exists?
  trial.is_default = !has_other_default
  trial.save!

  # 3) Пользователи (Person → User)
  say "👑 Создаём пользователей по ролям..."

  users_seed = [
    { phone: "77000000001", email: "admin@cloudsquares.local",         password: "UserPassword1@", role: :admin,         country_code: "RU", first_name: "John Doe 1" },
    { phone: "77000000002", email: "admin_manager@cloudsquares.local", password: "UserPassword1@", role: :admin_manager, country_code: "RU", first_name: "John Doe 2" },
    { phone: "77000000003", email: "agent_admin@cloudsquares.local",   password: "UserPassword1@", role: :agent_admin,   country_code: "RU", first_name: "John Doe 3" },
    { phone: "77000000004", email: "agent_manager@cloudsquares.local", password: "UserPassword1@", role: :agent_manager, country_code: "RU", first_name: "John Doe 4" },
    { phone: "77000000005", email: "agent@cloudsquares.local",         password: "UserPassword1@", role: :agent,         country_code: "RU", first_name: "John Doe 5" },
    { phone: "77000000006", email: "user@cloudsquares.local",          password: "UserPassword1@", role: :user,          country_code: "RU", first_name: "John Doe 6" }
  ]

  users_by_role = {}

  users_seed.each do |attrs|
    person = ensure_person!(attrs[:phone])
    user   = ensure_user!(
      person: person,
      email: attrs[:email],
      password: attrs[:password],
      role: attrs[:role],
      country_code: attrs[:country_code],
      is_active: true
    )
    users_by_role[attrs[:role].to_sym] = { user:, person:, first_name: attrs[:first_name] }
  end

  # 4) Демо-агентство + привязка сотрудников + контакты
  say "🏢 Создаём демо-агентство и привязываем агентские роли…"

  agent_admin_user = users_by_role.fetch(:agent_admin)[:user]

  agency = ensure_agency!(
    title: "Demo Realty",
    slug:  "demo-realty",
    created_by: agent_admin_user,
    agency_plan: trial # план обязателен
  )

  # Привязываем к агентству роли: agent_admin / agent_manager / agent
  %i[agent_admin agent_manager agent].each_with_index do |role, idx|
    bundle = users_by_role[role]
    next unless bundle

    user   = bundle[:user]
    person = bundle[:person]
    fname  = bundle[:first_name]

    ensure_user_agency!(
      user: user,
      agency: agency,
      is_default: true, # у каждого из этих пользователей это их дефолтное агентство
      status: :active
    )

    ensure_contact!(
      agency: agency,
      person: person,
      first_name: fname,
      email: user.email
    )
  end

  # admin и admin_manager — глобальные роли без привязки к агентству
end

say "✅ Готово! Страны, тариф, пользователи, агентство и контакты сидированы."

