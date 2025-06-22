# frozen_string_literal: true

module Api
  module V1
    class PropertyOwnersController < BaseController
      before_action :authenticate_user!
      before_action :set_property
      before_action :set_owner, only: %i[show update destroy]
      after_action :verify_authorized

      # GET /api/v1/properties/:property_id/owners
      def index
        authorize PropertyOwner
        owners = @property.property_owners.active
        render json: owners, each_serializer: PropertyOwnerSerializer
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

      def set_property
        @property = Property.find(params[:property_id])
      rescue ActiveRecord::RecordNotFound
        render_not_found("Объект недвижимости не найден", "properties.not_found")
      end

      def set_owner
        @owner = @property.property_owners.find_by(id: params[:id])
        render_not_found("Владелец не найден", "property_owners.not_found") unless @owner
      end

      def owner_params
        params.require(:property_owner).permit(
          :first_name, :last_name, :middle_name, :phone, :email, :notes, :user_id, :role
        )
      end
    end
  end
end
