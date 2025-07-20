# frozen_string_literal: true

module Customers
  # Сервис поиска или создания клиента по номеру телефона
  #
  # Если найден существующий Customer по телефону в рамках агентства — возвращает его.
  # Иначе создаёт нового Customer с заданными параметрами.
  #
  # @param [String] phone — номер телефона (нормализованный)
  # @param [Hash]   attributes — атрибуты для создания или дополнения (имя, услуга, и т.п.)
  #
  # @return [Customer] найденный или созданный клиент
  class CustomerFinderOrCreatorService
    attr_reader :phone, :attributes, :agency

    def initialize(phone:, attributes:, agency:)
      @phone = normalize_phone(phone)
      @attributes = attributes.deep_symbolize_keys
      @agency = agency
    end

    # Выполняет поиск или создание клиента
    #
    # @return [Customer]
    def call
      customer = find_existing_customer

      if customer.present?
        update_known_names(customer)
        update_known_phones(customer)
        customer
      else
        create_customer
      end
    end

    private

    # Находим клиента по совпадающему номеру телефона в рамках агентства
    def find_existing_customer
      agency.customers.with_phone(phone).first
    end

    def update_known_names(customer)
      full_name = full_name_from_attributes
      return if full_name.blank? || customer.names.include?(full_name)

      customer.names << full_name
      customer.save!
    end

    def update_known_phones(customer)
      return if customer.phones.include?(phone)

      customer.phones << phone
      customer.save!
    end

    def create_customer
      full_name = full_name_from_attributes

      agency.customers.create!(
        first_name: attributes[:first_name],
        last_name: attributes[:last_name],
        middle_name: attributes[:middle_name],
        service_type: attributes[:service_type] || :other,
        phones: [phone],
        names: full_name.present? ? [full_name] : [],
        user_id: attributes[:user_id],
        property_ids: attributes[:property_ids] || []
      )
    end

    def full_name_from_attributes
      [attributes[:last_name], attributes[:first_name], attributes[:middle_name]].compact.join(" ").strip
    end

    def normalize_phone(value)
      value.to_s.gsub(/\D/, "")
    end
  end
end
