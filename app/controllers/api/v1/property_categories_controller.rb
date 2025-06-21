# frozen_string_literal: true

module Api
  module V1
    class PropertyCategoriesController < BaseController
      before_action :authenticate_user!, only: %i[create update destroy]
      before_action :set_property_category, only: %i[update destroy]
      before_action :set_agency, only: %i[index show]
      after_action :verify_authorized, except: [:index, :show]

      # GET /api/v1/property_categories
      def index
        categories = @agency.property_categories.active.order(:position)
        render json: categories, each_serializer: PropertyCategorySerializer
      end

      # GET /api/v1/property_categories/:id
      def show
        property = @agency.property_categories.find_by!(id: params[:id])
        render json: property, serializer: PropertyCategorySerializer
      end

      # POST /api/v1/property_categories
      def create
        category = Current.agency.property_categories.new(category_params)
        authorize category

        if category.save
          render json: category, serializer: PropertyCategorySerializer, status: :created
        else
          render_validation_errors(category)
        end
      end

      # PATCH/PUT /api/v1/property_categories/:id
      def update
        authorize @property_category

        if @property_category.update(category_params)
          render json: @property_category, serializer: PropertyCategorySerializer
        else
          render_validation_errors(@property_category)
        end
      end

      # DELETE /api/v1/property_categories/:id
      def destroy
        authorize @property_category
        if @property_category.destroy
          render_success(
            key: "property_category.deleted",
            message: "Категория успешно удалена",
            code: 200
          )
        else
          render_validation_errors(@property_category)
        end
      end

      # Получить все характеристики недвижмости привязанной к этой категории
      def characteristics
        category = PropertyCategory.find(params[:id])
        authorize category, :characteristics?
        characteristics = category.property_characteristics.active.order(:position)
        render json: characteristics, each_serializer: PropertyCharacteristicSerializer
      end

      private

      def set_agency
        # TODO: в будущем убрать agency_id и искать агентство по host
        @agency = Agency.find_by!(id: public_params[:agency_id])
      rescue ActiveRecord::RecordNotFound
        render_not_found(
          key: "agency.not_found",
          message: "Агентство недвижимости не найдено"
        ) unless @agency
      end

      def set_property_category
        @property_category = Current.agency.property_categories.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found(
          key: "property_category.not_found",
          message: "Категория не найдена"
        ) unless @property_category
      end

      def public_params
        params.permit(:agency_id)
      end

      def category_params
        params.require(:property_category).permit(:title, :slug, :position, :parent_id, :is_active)
      end
    end
  end
end
