# frozen_string_literal: true

module Api
  module V1
    class PropertyBuyRequestsController < BaseController
      before_action :authenticate_user!, except: [:create]
      before_action :set_request, only: %i[show destroy update]
      after_action :verify_authorized

      # GET /api/v1/property_buy_requests?property_id=...
      def index
        authorize PropertyBuyRequest

        requests = if Current.user.role == "user"
          PropertyBuyRequest.active.where(agency_id: Current.agency.id, user_id: Current.user.id)
        else
          PropertyBuyRequest
            .active
            .where(agency_id: Current.agency.id)
        end

        requests = requests.where(property_id: params[:property_id]) if params[:property_id].present?
        requests = requests.includes(:property, :user).order(created_at: :desc)

        render json: requests, each_serializer: PropertyBuyRequestSerializer
      end

      # POST /api/v1/property_buy_requests
      def create
        request = PropertyBuyRequest.new(buy_request_params)

        if current_user
          request.user = current_user
          request.first_name ||= current_user&.first_name
          request.last_name ||= current_user&.last_name
          request.phone ||= current_user&.phone
        end

        # Автозаполнение agency_id через property
        request.agency_id = request.property.agency_id if request.property.present?

        authorize request

        if request.save
          render json: request, serializer: PropertyBuyRequestSerializer, status: :created
        else
          render_validation_errors(request)
        end
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
        @request = PropertyBuyRequest.find_by(id: params[:id])
        render_not_found("Заявка не найдена", "property_buy_requests.not_found") unless @request
      end

      def buy_request_params
        params.require(:property_buy_request).permit(
          :property_id, :first_name, :last_name, :phone, :comment
        )
      end

      def update_params
        params.require(:property_buy_request).permit(:status, :response_message)
      end
    end
  end
end
