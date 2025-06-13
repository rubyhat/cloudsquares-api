# frozen_string_literal: true

module Api
  module V1
    class AgencyPlansController < BaseController
      before_action :set_agency_plan, only: %i[show update destroy]
      before_action :authenticate_user!, except: %i[index show]
      after_action :verify_authorized, except: %i[index show]

      # GET /api/v1/agency_plans
      def index
        plans = AgencyPlan.active.order(:created_at)
        render json: plans, each_serializer: AgencyPlanSerializer
      end

      # GET /api/v1/agency_plans/:id
      def show
        render json: @agency_plan, serializer: AgencyPlanSerializer
      end

      # POST /api/v1/agency_plans
      def create
        @agency_plan = AgencyPlan.new(agency_plan_params)
        authorize @agency_plan

        if @agency_plan.save
          render json: @agency_plan, serializer: AgencyPlanSerializer, status: :created
        else
          render_validation_errors(@agency_plan)
        end
      end

      # PATCH/PUT /api/v1/agency_plans/:id
      def update
        authorize @agency_plan

        if @agency_plan.update(agency_plan_params)
          render json: @agency_plan, serializer: AgencyPlanSerializer
        else
          render_validation_errors(@agency_plan)
        end
      end

      # DELETE /api/v1/agency_plans/:id
      def destroy
        authorize @agency_plan

        unless @agency_plan.is_active?
          return render_error(
            key: "agency_plans.already_deleted",
            message: "Тариф уже деактивирован",
            status: :unprocessable_entity,
            code: 422
          )
        end

        if @agency_plan.soft_delete!
          render_success(
            key: "agency_plans.deleted",
            message: "Тарифный план успешно деактивирован",
            code: 200
          )
        else
          render_validation_errors(@agency_plan)
        end
      end


      private

      def set_agency_plan
        @agency_plan = AgencyPlan.find_by(id: params[:id])
        render_not_found(
          key: "agency_plans.not_found",
          message: "Тарифный план не найден"
        ) unless @agency_plan
      end

      def agency_plan_params
        params.require(:agency_plan).permit(
          :title,
          :description,
          :max_employees,
          :max_properties,
          :max_photos,
          :max_buy_requests,
          :max_sell_requests,
          :is_active,
          :is_custom
        )
      end
    end
  end
end
