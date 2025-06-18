# frozen_string_literal: true

module Api
  module V1
    class PropertyCharacteristicsController < BaseController
      before_action :authenticate_user!
      before_action :set_characteristic, only: %i[show update destroy]
      after_action :verify_authorized

      def index
        characteristics = Current.agency.property_characteristics.active.order(:position)
        authorize characteristics
        render json: characteristics, each_serializer: PropertyCharacteristicSerializer
      end

      def show
        authorize @characteristic
        render json: @characteristic, serializer: PropertyCharacteristicSerializer
      end

      def create
        characteristic = Current.agency.property_characteristics.new(characteristic_params)
        authorize characteristic

        if characteristic.save
          render json: characteristic, serializer: PropertyCharacteristicSerializer, status: :created
        else
          render_validation_errors(characteristic)
        end
      end

      def update
        authorize @characteristic

        if @characteristic.update(characteristic_params)
          render json: @characteristic, serializer: PropertyCharacteristicSerializer
        else
          render_validation_errors(@characteristic)
        end
      end

      def destroy
        authorize @characteristic
        if @characteristic.destroy
          render_success(
            key: "property_characteristic.deleted",
            message: "Характеристика успешно удалена",
            code: 200
          )
        else
          render_validation_errors(@characteristic)
        end
      end

      # Получить все категории, связанные с данной характеристикой
      def categories
        characteristic = Current.agency.property_characteristics.find(params[:id])
        authorize characteristic, :categories?

        categories = characteristic.property_categories.active.order(:position)
        render json: categories, each_serializer: PropertyCategorySerializer
      end


      private

      def set_characteristic
        @characteristic = Current.agency.property_characteristics.find(params[:id])
      end

      def characteristic_params
        params.require(:property_characteristic).permit(:title, :unit, :field_type, :position, :is_active)
      end
    end
  end
end
