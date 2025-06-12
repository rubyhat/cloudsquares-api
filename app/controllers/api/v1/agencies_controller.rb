# frozen_string_literal: true

module Api
  module V1
    class AgenciesController < BaseController
      before_action :set_agency, only: %i[show update destroy]
      before_action :authenticate_user!, except: %i[index show]
      after_action :verify_authorized, except: %i[index show]

      # GET /api/v1/agencies
      def index
        agencies = Agency.active
        render json: agencies, each_serializer: AgencySerializer
      end

      # GET /api/v1/agencies/:id
      def show
        render json: @agency, serializer: AgencySerializer
      end

      # POST /api/v1/agencies
      def create
        @agency = Agency.new(agency_params)
        @agency.created_by = current_user
        authorize @agency

        if @agency.save
          render json: @agency, serializer: AgencySerializer, status: :created
        else
          render_validation_errors(@agency)
        end
      end

      # PATCH/PUT /api/v1/agencies/:id
      def update
        authorize @agency

        if @agency.update(agency_params)
          render json: @agency, serializer: AgencySerializer
        else
          render_validation_errors(@agency)
        end
      end

      # DELETE /api/v1/agencies/:id
      def destroy
        authorize @agency

        unless @agency.is_active?
          return render_error(
            key: "agencies.already_deleted",
            message: "Агентство уже деактивировано",
            status: :unprocessable_entity,
            code: 422
          )
        end

        if @agency.soft_delete!
          render_success(
            key: "agencies.deleted",
            message: "Агентство недвижимости успешно деактивировано",
            code: 200
          )
        else
          render_validation_errors(@agency)
        end
      end

      private

      def set_agency
        @agency = Agency.find(params[:id])
      end

      def agency_params
        params.require(:agency).permit(:title, :slug, :custom_domain)
      end
    end
  end
end
