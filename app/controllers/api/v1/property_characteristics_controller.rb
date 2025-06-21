# frozen_string_literal: true

module Api
  module V1
    class PropertyCharacteristicsController < BaseController
      before_action :authenticate_user!
      before_action :set_characteristic, only: %i[show update destroy]
      after_action :verify_authorized

      # GET /api/v1/property_characteristics
      def index
        characteristics = Current.agency.property_characteristics.active.order(:position)
        authorize characteristics
        render json: characteristics, each_serializer: PropertyCharacteristicSerializer
      end

      # GET /api/v1/property_characteristics/:id
      def show
        authorize @characteristic
        render json: @characteristic, serializer: PropertyCharacteristicSerializer
      end

      # POST /api/v1/property_characteristics
      def create
        characteristic = Current.agency.property_characteristics.new(characteristic_params)
        authorize characteristic

        if characteristic.save
          render json: characteristic, serializer: PropertyCharacteristicSerializer, status: :created
        else
          render_validation_errors(characteristic)
        end
      end

      # PATCH/PUT /api/v1/property_characteristics/:id
      def update
        authorize @characteristic

        if @characteristic.update(characteristic_params)
          render json: @characteristic, serializer: PropertyCharacteristicSerializer
        else
          render_validation_errors(@characteristic)
        end
      end

      # DELETE /api/v1/property_characteristics/:id
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

      # GET /api/v1/property_characteristics/:id/categories
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

      # Поддержка вложенных параметров options_attributes
      def characteristic_params
        params.require(:property_characteristic).permit(
          :title, :unit, :field_type, :position, :is_active, :is_private,
          options_attributes: %i[id value _destroy position]
        )
      end
    end
  end
end
