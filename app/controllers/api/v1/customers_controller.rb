# frozen_string_literal: true

module Api
  module V1
    # CustomersController — CRUD для клиентов агентства.
    #
    # После перехода на Person/Contact:
    # - Создание клиента делегируем сервису Customers::CustomerFinderOrCreatorService,
    #   который делает upsert Person (по телефону) и Contact (в рамках Current.agency),
    #   затем find_or_create Customer(agency_id, contact_id).
    # - В index/show отдаём данные через сериализатор, который вытаскивает ФИО/телефон из contact/person.
    #
    # Безопасность:
    # - Все действия подчиняются CustomerPolicy.
    class CustomersController < BaseController
      before_action :set_customer, only: %i[show update destroy]
      after_action :verify_authorized

      # GET /api/v1/customers
      #
      # Возвращает клиентов текущего агентства.
      # Сериализатор отдаёт ФИО/телефон через contact/person.
      #
      # @return [void]
      def index
        authorize Customer
        scope = policy_scope(Customer)
                  .where(agency_id: Current.agency.id)
                  .includes(contact: :person)
                  .order(created_at: :desc)

        render json: scope, each_serializer: CustomerSerializer, status: :ok
      end

      # GET /api/v1/customers/:id
      #
      # @return [void]
      def show
        authorize @customer
        render json: @customer, serializer: CustomerSerializer, status: :ok
      end

      # POST /api/v1/customers
      #
      # Создание клиента через общий сервис:
      # - phone → Person (upsert по normalized_phone)
      # - first/last/middle/email/extra_phones/notes → Contact (агентский профиль)
      # - service_type/user_id → Customer
      #
      # Пример body:
      # {
      #   "customer": {
      #     "phone": "8 (700) 123-45-67",
      #     "first_name": "Иван",
      #     "last_name": "Иванов",
      #     "email": "ivan@example.com",
      #     "extra_phones": ["+7 700 000 00 00"],
      #     "service_type": "buy",
      #     "user_id": "UUID",
      #     "notes": "Комментарий менеджера (пишем и в Contact.notes, и в Customer.notes)"
      #   }
      # }
      #
      # @return [void]
      def create
        authorize Customer
        return render_forbidden(message: "Нет агентства по умолчанию") unless Current.agency

        cp = customer_params

        phone = cp[:phone].to_s
        if phone.blank?
          return render_error(
            key: "customers.phone_required",
            message: "Не указан номер телефона",
            status: :unprocessable_entity,
            code: 422
          )
        end

        normalized = ::Shared::PhoneNormalizer.normalize(phone)
        if normalized.blank?
          return render_error(
            key: "customers.phone_invalid",
            message: "Некорректный номер телефона",
            status: :unprocessable_entity,
            code: 422
          )
        end

        customer = nil

        ActiveRecord::Base.transaction do
          # 1) создаём/находим Person/Contact/Customer через сервис
          customer = Customers::CustomerFinderOrCreatorService.new(
            phone: normalized,
            attributes: {
              first_name:   cp[:first_name],
              last_name:    cp[:last_name],
              middle_name:  cp[:middle_name],
              email:        cp[:email],
              extra_phones: cp[:extra_phones],
              notes:        cp[:notes],        # попадёт в Contact.notes
              service_type: cp[:service_type],
              user_id:      cp[:user_id]
            },
            agency: Current.agency
          ).call

          # 2) при необходимости — сохраним заметку ещё и в самом Customer
          if cp[:notes].present?
            customer.update!(notes: cp[:notes])
          end

          authorize customer
        end

        render json: customer, serializer: CustomerSerializer, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      rescue ArgumentError => e
        render_error(
          key: "customers.invalid_arguments",
          message: e.message,
          status: :unprocessable_entity,
          code: 422
        )
      end

      # PATCH /api/v1/customers/:id
      #
      # Обновление смешанное:
      # - phone → @customer.person.normalized_phone (с учётом уникальности)
      # - first/last/middle/email/extra_phones → @customer.contact
      # - service_type/user_id/notes → @customer
      #
      # @return [void]
      def update
        authorize @customer
        cp = customer_params
        updated = false

        ActiveRecord::Base.transaction do
          # Обновление телефона в Person
          if cp[:phone].present?
            pn = ::Shared::PhoneNormalizer.normalize(cp[:phone])
            if pn.blank?
              return render_error(
                key: "customers.phone_invalid",
                message: "Некорректный номер телефона",
                status: :unprocessable_entity,
                code: 422
              )
            end
            @customer.person.update!(normalized_phone: pn)
            updated = true
          end

          # Обновление Contact
          if (%i[first_name last_name middle_name email extra_phones] & cp.keys).any?
            contact = @customer.contact
            contact.first_name  = cp[:first_name].presence || contact.first_name if cp.key?(:first_name)
            contact.last_name   = cp[:last_name]   if cp.key?(:last_name)
            contact.middle_name = cp[:middle_name] if cp.key?(:middle_name)
            contact.email       = cp[:email]       if cp.key?(:email)
            if cp.key?(:extra_phones)
              contact.extra_phones = Array(cp[:extra_phones])
                                       .map { |p| ::Shared::PhoneNormalizer.normalize(p) }
                                       .reject(&:blank?)
            end
            contact.save!
            updated = true
          end

          # Обновление полей Customer
          customer_updatable = {}
          customer_updatable[:service_type] = cp[:service_type] if cp.key?(:service_type)
          customer_updatable[:user_id]      = cp[:user_id]      if cp.key?(:user_id)
          customer_updatable[:notes]        = cp[:notes]        if cp.key?(:notes)

          if customer_updatable.any?
            unless @customer.update(customer_updatable)
              return render_validation_errors(@customer)
            end
            updated = true
          end
        end

        if updated
          render json: @customer, serializer: CustomerSerializer, status: :ok
        else
          render_success(
            key: "customers.nothing_to_update",
            message: "Нет данных для обновления",
            code: 200
          )
        end
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      rescue ActiveRecord::RecordNotUnique
        render_error(
          key: "customers.phone_conflict",
          message: "Этот номер телефона уже используется другой персоной",
          status: :unprocessable_entity,
          code: 422
        )
      end

      # DELETE /api/v1/customers/:id
      #
      # Мягкое удаление (is_active: false).
      #
      # @return [void]
      def destroy
        authorize @customer

        unless @customer.is_active
          return render_error(
            key: "customers.already_deleted",
            message: "Клиент уже удалён",
            status: :unprocessable_entity,
            code: 422
          )
        end

        if @customer.update(is_active: false)
          render_success(
            key: "customers.deleted",
            message: "Клиент успешно удалён",
            code: 200
          )
        else
          render_validation_errors(@customer)
        end
      end

      private

      # Находит клиента в пределах текущего агентства.
      #
      # @return [void]
      def set_customer
        @customer = Customer
                      .where(agency_id: Current.agency.id)
                      .includes(contact: :person)
                      .find_by(id: params[:id])
        render_not_found("Клиент не найден", "customers.not_found") unless @customer
      end

      # Разрешённые параметры.
      #
      # Внимание:
      # - :phone теперь относится к Person (normalized_phone)
      # - first/last/middle/email/extra_phones — к Contact
      # - service_type/user_id/notes — к Customer
      #
      # @return [ActionController::Parameters]
      def customer_params
        params.require(:customer).permit(
          :phone,        # Person.normalized_phone
          :email,        # Contact.email
          :first_name,   # Contact.first_name
          :last_name,    # Contact.last_name
          :middle_name,  # Contact.middle_name
          :service_type, # Customer.service_type
          :user_id,      # Customer.user_id
          :notes,        # Customer.notes (+ дублируем в Contact.notes при создании)
          extra_phones:  [] # Contact.extra_phones
        )
      end
    end
  end
end
