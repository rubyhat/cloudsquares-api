module Api
  module V1
    class PropertiesController < BaseController
      before_action :authenticate_user!, except: %i[index show]
      before_action :set_property, only: %i[show update destroy]
      after_action :verify_authorized

      def index
        authorize Property
        # TODO: Определять недвижимость агентства по имени хосту в продакшене! Сейчас временно передаем айди черзе параметры
        properties = if Current.guest?
           Property.available.where(status: :active, agency_id: temp_params[:agency_id]).includes(:property_location)
        else
           Property.available.where( agency_id: temp_params[:agency_id]).includes(:property_location)
        end

        render json: properties, each_serializer: PropertySerializer
      end

      def show
        @property = Property.find(params[:id])
        authorize @property

        # TODO: надо подумать, будем ли отдавать на просмотр удаленные объекты(отображать как "объявление в архиве") и другие статусы, кроме active ?
        if !@property.active? && (Current.guest? || Current.user&.role == "user")
          return render_error(
            key: "properties.not_ready_to_view",
            message: "Объект недвижимости еще не готов к просмотру",
            status: :not_found,
            code: 404
          )
        end

        unless @property.is_active?
          return render_error(
            key: "properties.inactive",
            message: "Объект недвижимости был деактивирован",
            status: :not_found,
            code: 404
          ) unless  current_user&.admin? || current_user&.admin_manager?
        end

        render json: @property, serializer: PropertySerializer, status: :ok
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

      def temp_params
        params.permit(:agency_id)
      end

      def set_property
        @property = Property.find(params[:id])
      end

      def property_params
        params.require(:property).permit(
          :title, :description, :price, :discount,
          :listing_type, :status, :category_id,
          property_location_attributes: %i[
            country region city street house_number map_link is_info_hidden
            country_code region_code city_code geo_city_id
          ],
          property_characteristic_values_attributes: %i[ property_characteristic_id value ]
        )
      end
    end
  end
end
