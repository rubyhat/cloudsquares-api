# frozen_string_literal: true

module Api
  module V1
    class CustomersController < BaseController
      before_action :set_customer, only: %i[show update destroy]
      after_action :verify_authorized

      # GET /api/v1/customers
      #
      # Возвращает клиентов текущего агентства.
      # Сериализатор отдаёт ФИО/телефон через contact/person для обратной совместимости.
      def index
        authorize Customer
        scope = policy_scope(Customer)
                  .where(agency_id: Current.agency.id)
                  .includes(contact: :person)
                  .order(created_at: :desc)

        render json: scope, each_serializer: CustomerSerializer, status: :ok
      end

      # GET /api/v1/customers/:id
      def show
        authorize @customer
        render json: @customer, serializer: CustomerSerializer, status: :ok
      end

      # POST /api/v1/customers
      #
      # Создание клиента:
      # - phone → Person (upsert по normalized_phone)
      # - (first/last/middle/email/extra_phones) → Contact (в рамках Current.agency)
      # - сам Customer получает contact_id и прочие поля (service_type, notes, user_id).
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

        normalized = PhoneNormalizer.normalize(phone)
        if normalized.blank?
          return render_error(
            key: "customers.phone_invalid",
            message: "Некорректный номер телефона",
            status: :unprocessable_entity,
            code: 422
          )
        end

        ActiveRecord::Base.transaction do
          # 1) Person по телефону
          person = Person.find_or_create_by!(normalized_phone: normalized)

          # 2) Contact в рамках агентства
          contact = Contact.find_or_initialize_by(agency_id: Current.agency.id, person_id: person.id)
          contact.first_name  = cp[:first_name].presence || contact.first_name || "—"
          contact.last_name   = cp.key?(:last_name)   ? cp[:last_name]   : contact.last_name
          contact.middle_name = cp.key?(:middle_name) ? cp[:middle_name] : contact.middle_name
          contact.email       = cp.key?(:email)       ? cp[:email]       : contact.email
          if cp[:extra_phones].present?
            contact.extra_phones = Array(cp[:extra_phones]).map { |p| PhoneNormalizer.normalize(p) }.reject(&:blank?)
          end
          contact.save!

          # 3) Customer
          @customer = Customer.new(
            agency_id:    Current.agency.id,
            user_id:      cp[:user_id],
            contact_id:   contact.id,
            service_type: cp[:service_type],
            notes:        cp[:notes],
            is_active:    true
          )
          authorize @customer

          if @customer.save
            render json: @customer, serializer: CustomerSerializer, status: :created
          else
            render_validation_errors(@customer)
          end
        end
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      end

      # PATCH /api/v1/customers/:id
      #
      # Обновление:
      # - если пришёл phone — обновляем person.normalized_phone (учитываем уникальность);
      # - если пришли ФИО/email/extra_phones — правим contact;
      # - прочие поля — в Customer.
      def update
        authorize @customer
        cp = customer_params
        updated = false

        ActiveRecord::Base.transaction do
          # Обновление телефона в Person
          if cp[:phone].present?
            pn = PhoneNormalizer.normalize(cp[:phone])
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
              contact.extra_phones = Array(cp[:extra_phones]).map { |p| PhoneNormalizer.normalize(p) }.reject(&:blank?)
            end
            contact.save!
            updated = true
          end

          # Обновление полей самого Customer
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
        # В т.ч. конфликт уникальности телефона в people
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

      def set_customer
        @customer = Customer
                      .where(agency_id: Current.agency.id)
                      .includes(contact: :person)
                      .find_by(id: params[:id])
        render_not_found("Клиент не найден", "customers.not_found") unless @customer
      end

      # Разрешённые параметры.
      # Обрати внимание:
      # - :phone теперь используется для Person
      # - first/last/middle/email/extra_phones — для Contact
      # - остальные поля — для Customer
      def customer_params
        params.require(:customer).permit(
          :phone,        # Person.normalized_phone
          :email,        # Contact.email (агентский email)
          :first_name,   # Contact.first_name
          :last_name,    # Contact.last_name
          :middle_name,  # Contact.middle_name
          :service_type, # Customer.service_type
          :user_id,      # Customer.user_id (если привязан к учётке)
          :notes,        # Customer.notes
          extra_phones:  [] # Contact.extra_phones (массив строк)
        )
      end
    end
  end
end
