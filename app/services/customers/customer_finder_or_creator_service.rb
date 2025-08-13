# frozen_string_literal: true

module Customers
  # Сервис поиска или создания клиента агентства по телефону.
  #
  # Алгоритм (idempotent):
  # 1) Нормализуем phone -> Shared::PhoneNormalizer.
  # 2) upsert Person(normalized_phone).
  # 3) upsert Contact(agency_id, person_id) — заполняем ФИО/e-mail/extra_phones/notes.
  # 4) find_or_create_by Customer(agency_id, contact_id) — задаём service_type, user_id, is_active.
  #
  # Возвращает Customer; связанные объекты доступны как:
  #   customer.contact
  #   customer.contact.person
  #
  # Входные attributes поддерживают:
  #   :first_name, :last_name, :middle_name, :email, :extra_phones, :notes,
  #   :service_type (строка/символ из Customer.service_types), :user_id
  #
  # Ошибки:
  # - ArgumentError при пустом/некорректном телефоне или agency=nil.
  # - ActiveRecord::RecordInvalid / RecordNotUnique в случае валидаций/гоночных условий.
  class CustomerFinderOrCreatorService
    # @return [String] нормализованный телефон
    attr_reader :phone
    # @return [Hash] атрибуты для Contact/Customer
    attr_reader :attributes
    # @return [Agency]
    attr_reader :agency

    # @param phone [String] телефон в любом формате
    # @param attributes [Hash] произвольные атрибуты (см. описание выше)
    # @param agency [Agency] агентство, в контексте которого создаём Contact/Customer
    def initialize(phone:, attributes:, agency:)
      normalized = ::Shared::PhoneNormalizer.normalize(phone)
      raise ArgumentError, "Invalid phone" if normalized.blank?
      raise ArgumentError, "Agency required" if agency.nil?

      @phone      = normalized
      @attributes = (attributes || {}).deep_symbolize_keys
      @agency     = agency
    end

    # Выполняет поиск или создание клиента
    #
    # @return [Customer]
    def call
      ActiveRecord::Base.transaction do
        person  = ensure_person!
        contact = ensure_contact!(person)
        ensure_customer!(contact)
      end
    end

    private

    # Находит или создаёт Person по normalized_phone.
    #
    # @return [Person]
    def ensure_person!
      Person.find_or_create_by!(normalized_phone: phone)
    end

    # Находит или создаёт Contact внутри агентства для заданной Person.
    # Обновляет ФИО, email, extra_phones, notes при наличии в attributes.
    #
    # @param person [Person]
    # @return [Contact]
    def ensure_contact!(person)
      contact = Contact.find_or_initialize_by(agency_id: agency.id, person_id: person.id)

      # ФИО: допускаем частичное заполнение; first_name ставим "—" если вообще пусто.
      if attributes.key?(:first_name)
        contact.first_name = presence_or(contact.first_name, attributes[:first_name], fallback: "—")
      else
        contact.first_name ||= "—"
      end
      contact.last_name   = attributes[:last_name]   if attributes.key?(:last_name)
      contact.middle_name = attributes[:middle_name] if attributes.key?(:middle_name)

      # E-mail
      contact.email = attributes[:email] if attributes.key?(:email)

      # Дополнительные телефоны: нормализуем, мержим со старыми, удаляем пустые/дубли.
      if attributes.key?(:extra_phones)
        incoming = Array(attributes[:extra_phones])
                     .map { |p| ::Shared::PhoneNormalizer.normalize(p) }
                     .compact
        current  = Array(contact.extra_phones).compact
        contact.extra_phones = (current + incoming).uniq
      end

      # Заметки
      contact.notes = attributes[:notes] if attributes.key?(:notes)

      # Флаг не удалён
      contact.is_deleted = false if contact.has_attribute?(:is_deleted)

      contact.save!
      contact
    end

    # Находит существующего или создаёт нового Customer для данного Contact в агентстве.
    # Устанавливает service_type (по умолчанию :buy) и user_id (если передан).
    #
    # @param contact [Contact]
    # @return [Customer]
    def ensure_customer!(contact)
      customer = Customer.find_or_initialize_by(agency_id: agency.id, contact_id: contact.id)

      # service_type — валидируем по enum
      if attributes.key?(:service_type)
        st = attributes[:service_type].to_s
        if Customer.service_types.key?(st)
          customer.service_type = st
        end
      else
        # разумный дефолт для входящих лидов с телефона
        customer.service_type ||= :buy
      end

      # user_id (если лид пришёл от авторизованного пользователя)
      customer.user_id = attributes[:user_id] if attributes.key?(:user_id)

      # Активируем запись
      customer.is_active = true if customer.has_attribute?(:is_active)

      customer.save!
      customer
    end

    # Возвращает первый непустой аргумент, иначе fallback.
    #
    # @param current [String, nil]
    # @param incoming [String, nil]
    # @param fallback [String]
    # @return [String]
    def presence_or(current, incoming, fallback:)
      inc = incoming.to_s.strip
      return inc unless inc.empty?
      cur = current.to_s.strip
      return cur unless cur.empty?
      fallback
    end
  end
end
