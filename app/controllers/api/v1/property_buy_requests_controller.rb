# frozen_string_literal: true

# Контроллер заявок на покупку недвижимости.
# Переведён на Person/Contact:
# - В create выполняем upsert Person по телефону, затем Contact внутри агентства,
#   далее создаём/находим Customer для этого Contact и сохраним ссылку в заявке.
# - В update меняем только статус/response_message (как и прежде).
#
# Безопасность:
# - index/show ограничены текущим агентством; "user" видит только свои заявки.
# - set_request использует includes для избежания N+1.
module Api
  module V1
    class PropertyBuyRequestsController < BaseController
      before_action :authenticate_user!, except: [:create]
      before_action :set_request, only: %i[show destroy update]
      after_action :verify_authorized

      # GET /api/v1/property_buy_requests?property_id=...
      #
      # Возвращает список заявок текущего агентства.
      # Если текущий пользователь имеет роль "user" (B2C), ему показываем только его заявки.
      def index
        authorize PropertyBuyRequest

        base_scope = PropertyBuyRequest
                       .active
                       .where(agency_id: Current.agency.id)

        requests = if Current.user&.role == "user"
                     base_scope.where(user_id: Current.user.id)
                   else
                     base_scope
                   end

        requests = requests.where(property_id: params[:property_id]) if params[:property_id].present?
        requests = requests.includes(:property, :user, contact: :person).order(created_at: :desc)

        render json: requests, each_serializer: PropertyBuyRequestSerializer
      end

      # POST /api/v1/property_buy_requests
      #
      # Тело запроса:
      # {
      #   "property_buy_request": {
      #     "property_id": "UUID",           # обязательно
      #     "first_name": "Иван",            # -> Contact.first_name (если гость)
      #     "last_name": "Иванов",           # -> Contact.last_name (если гость)
      #     "phone": "77001234567",          # -> Person.normalized_phone (если гость)
      #     "comment": "Текст комментария"
      #   }
      # }
      #
      # Если пользователь авторизован:
      # - user_id := current_user.id
      # - телефон берём из current_user.person.normalized_phone
      # - имя берём из Contact пользователя в этом агентстве (если есть), иначе используем переданные first_name/last_name
      def create
        # Разбираем вход
        attrs = buy_request_params
        property = Property.find_by(id: attrs[:property_id])

        unless property
          return render_not_found("Объект недвижимости не найден", "properties.not_found")
        end

        agency = property.agency
        # Базовый объект заявки: только связанные ID + комментарий
        request = PropertyBuyRequest.new(
          property_id: property.id,
          agency_id:   agency.id,
          comment:     attrs[:comment]
        )

        # Пользователь и исходные ФИО/телефон
        current_person_phone = current_user&.person&.normalized_phone
        input_phone          = attrs[:phone].to_s

        phone_for_person =
          if current_user.present?
            current_person_phone
          else
            PhoneNormalizer.normalize(input_phone)
          end

        if phone_for_person.blank?
          return render_error(
            key: "property_buy_requests.phone_required",
            message: "Не указан или некорректен номер телефона",
            status: :unprocessable_entity,
            code: 422
          )
        end

        # Попытаемся найти контакт пользователя в этом агентстве (если он авторизован)
        contact_first_name = attrs[:first_name]
        contact_last_name  = attrs[:last_name]

        ActiveRecord::Base.transaction do
          # 1) Person по телефону
          person = Person.find_or_create_by!(normalized_phone: phone_for_person)

          # 2) Contact внутри агентства
          contact = Contact.find_or_initialize_by(agency_id: agency.id, person_id: person.id)

          # Если пользователь авторизован — пробуем взять имя из его агентского контакта
          if current_user
            existing_user_contact = Contact.find_by(agency_id: agency.id, person_id: current_user.person_id)
            if existing_user_contact
              contact_first_name ||= existing_user_contact.first_name
              contact_last_name  ||= existing_user_contact.last_name
            end
          end

          contact.first_name = contact_first_name.presence || contact.first_name || "—"
          contact.last_name  = contact_last_name   if contact_last_name.present? || contact.last_name.blank?
          contact.save!

          # 3) Customer для этого контакта в агентстве (service_type: buy)
          customer = Customer.find_or_create_by!(agency_id: agency.id, contact_id: contact.id) do |c|
            c.service_type = :buy
            c.user_id      = current_user&.id
            c.is_active    = true
          end

          # 4) Завершаем заявку
          request.user     = current_user if current_user
          request.contact  = contact
          request.customer = customer

          authorize request

          if request.save
            render json: request, serializer: PropertyBuyRequestSerializer, status: :created
          else
            render_validation_errors(request)
          end
        end
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      end

      # GET /api/v1/property_buy_requests/:id
      def show
        authorize @request

        if @request.is_deleted?
          return render_error(
            key: "property_buy_requests.deleted",
            message: "Заявка была удалена",
            status: :unprocessable_entity,
            code: 422
          )
        end

        render json: @request, serializer: PropertyBuyRequestSerializer
      end

      # PATCH /api/v1/property_buy_requests/:id
      #
      # Меняем только статус и/или ответ менеджера.
      def update
        authorize @request

        if @request.update(update_params)
          render json: @request, serializer: PropertyBuyRequestSerializer
        else
          render_validation_errors(@request)
        end
      end

      # DELETE /api/v1/property_buy_requests/:id
      def destroy
        authorize @request

        if @request.is_deleted?
          return render_error(
            key: "property_buy_requests.already_deleted",
            message: "Заявка уже удалена",
            status: :unprocessable_entity,
            code: 422
          )
        end

        if @request.soft_delete!
          render_success(
            key: "property_buy_requests.deleted",
            message: "Заявка успешно удалена",
            code: 200
          )
        else
          render_validation_errors(@request)
        end
      end

      private

      def set_request
        @request = PropertyBuyRequest
                     .where(agency_id: Current.agency.id)
                     .includes(:property, :user, contact: :person)
                     .find_by(id: params[:id])

        render_not_found("Заявка не найдена", "property_buy_requests.not_found") unless @request
      end

      # Разрешённые параметры для создания заявки.
      # ВНИМАНИЕ: first_name / last_name / phone — НЕ поля модели заявки,
      # они используются для upsert Person/Contact и не присваиваются в PropertyBuyRequest напрямую.
      def buy_request_params
        params.require(:property_buy_request).permit(
          :property_id,
          :first_name,
          :last_name,
          :phone,
          :comment
        )
      end

      # Разрешённые параметры для обновления заявки.
      def update_params
        params.require(:property_buy_request).permit(:status, :response_message)
      end
    end
  end
end
