# frozen_string_literal: true

module Api
  module V1
    class AgenciesController < BaseController
      before_action :set_agency, only: %i[show update destroy change_plan]
      before_action :authenticate_user!, except: %i[index show change_plan]
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

        ActiveRecord::Base.transaction do
          # Назначаем тарифный план
          plan = if agency_params[:agency_plan_id].present?
           AgencyPlan.find(agency_params[:agency_plan_id])
          else
           AgencyPlan.find_by!(is_default: true)
          end

          # Обработка случая: тарифный план не найден
          unless plan
            return render_error(
              key: "agency_plans.not_found",
              message: "Указанный тарифный план не существует или отключён",
              status: :unprocessable_entity,
              code: 422
            )
          end

          # Проверка прав через Pundit
          authorize plan, :assign_to_agency?

          @agency.agency_plan = plan
          @agency.save!

          # Привязка пользователя к агентству
          UserAgency.create!(
            user: current_user,
            agency: @agency,
            is_default: true,
            status: :active
          )
        end

        render json: @agency, serializer: AgencySerializer, status: :created

      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
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

      # Смена тарифного плана
      def change_plan
        authorize @agency, :change_plan?

        plan = AgencyPlan.find_by(id: params[:agency_plan_id])

        unless plan.present? && plan.is_active?
          return render_error(
            key: "agency_plans.not_found",
            message: "Указанный тарифный план не существует или отключён",
            status: :unprocessable_entity,
            code: 422
          )
        end

        # Только если plan гарантированно не nil:
        authorize plan, :assign_to_agency?

        @agency.update!(agency_plan: plan)

        render_success(
          key: "agencies.plan_updated",
          message: "Тарифный план успешно обновлён"
        )
      rescue ActiveRecord::RecordNotFound
        render_not_found
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
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
        params.require(:agency).permit(:title, :slug, :custom_domain, :agency_plan_id)
      end
    end
  end
end
