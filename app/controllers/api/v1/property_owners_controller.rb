# frozen_string_literal: true

module Api
  module V1
    class PropertyOwnersController < BaseController
      before_action :authenticate_user!
      before_action :set_property
      before_action :set_owner, only: %i[show update destroy]
      after_action :verify_authorized

      # GET /api/v1/properties/:property_id/owners
      #
      # Возвращает пагинированный список владельцев объекта недвижимости.
      #
      # Query params:
      # - per_page: Integer — количество элементов на странице (по умолчанию 20, максимум 100)
      # - page:     Integer — номер страницы, начиная с 1 (по умолчанию 1)
      #
      # Формат ответа:
      # {
      #   data:  [ ... PropertyOwnerSerializer ... ],
      #   pages: Integer,  # всего страниц (ceil(total / per_page))
      #   total: Integer   # всего записей без учёта пагинации
      # }
      def index
        authorize PropertyOwner

        # Базовый скоуп: только активные владельцы конкретного объекта
        scope = @property.property_owners.active.order(created_at: :desc)

        # Параметры пагинации с безопасными значениями по умолчанию и ограничениями
        per_page = pagination_params[:per_page].to_i
        page     = pagination_params[:page].to_i

        per_page = 20 if per_page <= 0
        per_page = 100 if per_page > 100 # верхний кап, чтобы не уронить БД
        page = 1 if page <= 0

        # Подсчёт метрик до применения offset/limit
        total = scope.count
        pages = (total.to_f / per_page).ceil

        owners = scope.offset((page - 1) * per_page).limit(per_page)

        render json: {
          data: ActiveModelSerializers::SerializableResource.new(
            owners,
            each_serializer: PropertyOwnerSerializer
          ).as_json,
          pages: pages,
          total: total
        }
      end

      # GET /api/v1/properties/:property_id/owners/:id
      def show
        authorize @owner
        render json: @owner, serializer: PropertyOwnerSerializer
      end

      # POST /api/v1/properties/:property_id/owners
      def create
        if @property.property_owners.active.count >= 5
          return render_error(
            key: "property_owners.limit_exceeded",
            message: "Достигнут лимит в 5 владельцев для одного объекта",
            status: :unprocessable_entity,
            code: 422
          )
        end

        owner = @property.property_owners.build(owner_params)
        authorize owner

        if owner.save
          render json: owner, serializer: PropertyOwnerSerializer, status: :created
        else
          render_validation_errors(owner)
        end
      end

      # PATCH /api/v1/properties/:property_id/owners/:id
      def update
        authorize @owner

        if @owner.update(owner_params)
          render json: @owner, serializer: PropertyOwnerSerializer
        else
          render_validation_errors(@owner)
        end
      end

      # DELETE /api/v1/properties/:property_id/owners/:id
      def destroy
        authorize @owner

        if @owner.is_deleted?
          return render_error(
            key: "property_owners.already_deleted",
            message: "Владелец уже деактивирован",
            status: :unprocessable_entity,
            code: 422
          )
        end

        if @owner.soft_delete!
          render_success(
            key: "property_owners.deleted",
            message: "Владелец недвижимости деактивирован",
            code: 200
          )
        else
          render_validation_errors(@owner)
        end
      end

      private

      # Безопасный парсинг query‑параметров пагинации
      #
      # @return [ActionController::Parameters] разрешённые параметры { per_page, page }
      def pagination_params
        params.permit(:per_page, :page)
      end

      # Поиск объекта недвижимости, к которому относятся владельцы
      def set_property
        @property = Property.find(params[:property_id])
      rescue ActiveRecord::RecordNotFound
        render_not_found("Объект недвижимости не найден", "properties.not_found")
      end

      # Поиск конкретного владельца внутри объекта
      def set_owner
        @owner = @property.property_owners.find_by(id: params[:id])
        render_not_found("Владелец не найден", "property_owners.not_found") unless @owner
      end

      # Разрешённые параметры для create/update
      def owner_params
        params.require(:property_owner).permit(
          :first_name, :last_name, :middle_name, :phone, :email, :notes, :user_id, :role
        )
      end
    end
  end
end
