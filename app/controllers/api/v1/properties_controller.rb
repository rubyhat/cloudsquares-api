module Api
  module V1
    class PropertiesController < BaseController
      before_action :authenticate_user!, except: %i[index show]
      before_action :set_property, only: %i[show update destroy]
      after_action :verify_authorized

      def index
        authorize Property
        properties = Property.active.where(agency_id: Current.agency.id).includes(:property_location)
        render json: properties, each_serializer: PropertySerializer
      end

      def show
        @property = Property.find(params[:id])

        unless @property.is_active?
          return render_error(
            key: "properties.inactive",
            message: "Объект недвижимости был деактивирован",
            status: :not_found,
            code: 404
          ) unless current_user&.admin? || current_user&.admin_manager?
        end

        if @property.active? || current_user.present?
          authorize @property
          render json: @property, serializer: PropertySerializer
        else
          render_not_found
        end
      end

      def create
        property = Property.new(property_params)
        property.agency_id = Current.agency.id
        property.agent_id = Current.user.id
        property.status = Property.statuses[:pending]

        authorize property
        LimitChecker.check!(:properties, Current.agency)

        if property.save
          render json: property, serializer: PropertySerializer, status: :created
        else
          render_validation_errors(property)
        end
      end

      def update
        authorize @property
        if @property.update(property_params)
          render json: @property, serializer: PropertySerializer
        else
          render_validation_errors(@property)
        end
      end

      def destroy
        authorize @property

        unless @property.is_active?
          return render_error(
            key: "properties.already_deleted",
            message: "Объект недвижимости уже деактивирован",
            status: :unprocessable_entity,
            code: 422
          )
        end

        if @property.soft_delete!
          render_success(
            key: "properties.deleted",
            message: "Объект недвижимости успешно деактивирован",
            code: 200
          )
        else
          render_validation_errors(@property)
        end
      end


      private

      def set_property
        @property = Property.find(params[:id])
      end

      def property_params
        params.require(:property).permit(
          :title, :description, :price, :discount,
          :listing_type, :status, :category_id
        )
      end
    end
  end
end
