# frozen_string_literal: true

module Api
  module V1
    # Контроллер заявок на покупку недвижимости.
    #
    # Создание заявки теперь использует Customers::CustomerFinderOrCreatorService:
    # - определяем телефон (из current_user.person или из params с нормализацией);
    # - upsert Person/Contact/Customer в контексте агентства объекта;
    # - в заявку пишем :contact и :customer (а не «сырые» first_name/phone).
    class PropertyBuyRequestsController < BaseController
      before_action :authenticate_user!, except: [:create]
      before_action :set_request, only: %i[show destroy update]
      after_action :verify_authorized

      # GET /api/v1/property_buy_requests?property_id=...
      #
      # Возвращает список заявок текущего агентства.
      # Если пользователь — B2C (:user), ему показываем только его заявки.
      #
      # @return [void]
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
      #     "property_id": "UUID",
      #     "first_name": "Иван",   # опционально, если гость
      #     "last_name": "Иванов",  # опционально, если гость
      #     "phone": "77001234567", # опционально, если гость
      #     "comment": "Текст комментария"
      #   }
      # }
      #
      # Если пользователь авторизован:
      # - user_id := current_user.id
      # - телефон берём из current_user.person.normalized_phone
      # - имя пробуем взять из его Contact в этом агентстве.
      #
      # @return [void]
      def create
        attrs     = buy_request_params
        property  = Property.find_by(id: attrs[:property_id])

        unless property
          return render_not_found("Объект недвижимости не найден", "properties.not_found")
        end

        agency = property.agency

        # Определяем телефон
        phone_for_person =
          if current_user.present?
            current_user.person&.normalized_phone
          else
            ::Shared::PhoneNormalizer.normalize(attrs[:phone].to_s)
          end

        if phone_for_person.blank?
          return render_error(
            key: "property_buy_requests.phone_required",
            message: "Не указан или некорректен номер телефона",
            status: :unprocessable_entity,
            code: 422
          )
        end

        # Собираем атрибуты для клиента (service_type: :buy)
        # Если пользователь авторизован и уже имеет Contact в этом агентстве,
        # имя подтянется сериализатором; здесь же передаём first/last на случай гостя.
        customer = nil
        contact  = nil

        ActiveRecord::Base.transaction do
          customer = Customers::CustomerFinderOrCreatorService.new(
            phone: phone_for_person,
            attributes: {
              first_name:  attrs[:first_name],
              last_name:   attrs[:last_name],
              service_type: :buy,
              user_id:     current_user&.id
            },
            agency: agency
          ).call

          contact = customer.contact

          request = PropertyBuyRequest.new(
            property_id: property.id,
            agency_id:   agency.id,
            user_id:     current_user&.id,
            contact_id:  contact.id,
            customer_id: customer.id,
            comment:     attrs[:comment]
          )

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
      #
      # @return [void]
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
      #
      # @return [void]
      def update
        authorize @request

        if @request.update(update_params)
          render json: @request, serializer: PropertyBuyRequestSerializer
        else
          render_validation_errors(@request)
        end
      end

      # DELETE /api/v1/property_buy_requests/:id
      #
      # Мягкое удаление.
      #
      # @return [void]
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

      # Находит заявку в пределах текущего агентства.
      #
      # @return [void]
      def set_request
        @request = PropertyBuyRequest
                     .where(agency_id: Current.agency.id)
                     .includes(:property, :user, contact: :person)
                     .find_by(id: params[:id])

        render_not_found("Заявка не найдена", "property_buy_requests.not_found") unless @request
      end

      # Разрешённые параметры создания заявки.
      #
      # ВАЖНО: first_name / last_name / phone — это не поля заявки,
      # а вспомогательные данные для создания Person/Contact/Customer.
      #
      # @return [ActionController::Parameters]
      def buy_request_params
        params.require(:property_buy_request).permit(
          :property_id,
          :first_name,
          :last_name,
          :phone,
          :comment
        )
      end

      # Разрешённые параметры обновления заявки.
      #
      # @return [ActionController::Parameters]
      def update_params
        params.require(:property_buy_request).permit(:status, :response_message)
      end
    end
  end
end
