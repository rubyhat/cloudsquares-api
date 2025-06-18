# frozen_string_literal: true

module Api
  module V1
    class PropertyCategoryCharacteristicsController < BaseController
      before_action :authenticate_user!
      after_action :verify_authorized

      # POST /api/v1/property_category_characteristics
      def create
        record = PropertyCategoryCharacteristic.new(permitted_params)
        authorize record

        if record.save
          render json: record, status: :created
        else
          render_validation_errors(record)
        end
      end

      # DELETE /api/v1/property_category_characteristics/:id
      def destroy
        record = PropertyCategoryCharacteristic.find(params[:id])
        authorize record

        if record.destroy
          render_success(key: "property_category_characteristics.deleted", message: "Связь удалена", code: 200)
        else
          render_validation_errors(record)
        end
      end

      private

      def permitted_params
        params.require(:property_category_characteristic).permit(:property_category_id, :property_characteristic_id, :position)
      end
    end
  end
end
