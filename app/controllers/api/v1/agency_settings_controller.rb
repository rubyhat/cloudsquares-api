# frozen_string_literal: true
module Api
  module V1
    class AgencySettingsController < BaseController
      before_action :set_agency_setting, only: [:show, :update]
      skip_before_action :authenticate_user!, only: [:show]
      after_action :verify_authorized, except: [:show, :my_agency]

      # GET /api/v1/agency_settings/:id
      def show
        render json: @agency_setting
      end

      # GET /api/v1/my_agency/setting
      #
      # Возвращает настройки текущего агентства
      def my_agency
        return render_unauthorized unless current_user && current_agency

        setting = current_agency.agency_setting
        return render_not_found unless setting

        render json: setting
      end

      # PATCH/PUT /api/v1/agency_settings/:id
      def update
        authorize @agency_setting

        if @agency_setting.update(agency_setting_params)
          render json: @agency_setting
        else
          render_validation_errors(@agency_setting)
        end
      end

      private

      def set_agency_setting
        @agency_setting = AgencySetting.find(params[:id])
        rescue ActiveRecord::RecordNotFound
        render_not_found(
          key: "agency_setting.not_found",
          message: "Настройки агентства не найдены"
        ) unless @agency_setting

      end

      def agency_setting_params
        params.require(:agency_setting).permit(
          :site_title, :site_description, :color_scheme, :logo_url,
          :locale, :timezone, :home_page_content,
          :contacts_page_content, :meta_keywords, :meta_description
        )
      end
    end
  end
end
