# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include ApiErrorHandling
      include Pundit::Authorization
      include PaginationConcern

      rescue_from Pundit::NotAuthorizedError, with: :render_pundit_forbidden

      before_action :set_locale
      before_action :authenticate_user!, unless: -> { public_access_allowed? }
      before_action { Current.user = current_user }
      before_action :set_current_agency

      def set_locale
        I18n.locale = request.headers["X-Locale"] || I18n.default_locale
      end

      def public_access_allowed?
        # Переопределяется в контроллерах
        false
      end

      private


      def set_current_agency
        return unless current_user

        # 1) Сотрудники: берём дефолтное агентство из UserAgency
        agency = current_user&.user_agencies&.find_by(is_default: true)&.agency
        if agency.present?
          @current_agency = agency
          Current.agency  = agency
          return
        end

        # 2) B2C: если в access-токене есть agency_id — используем его как контекст
        token   = request.headers["Authorization"]&.split&.last
        payload = Auth::JwtService.decode_and_verify(token)
        if payload && payload["agency_id"].present?
          a = Agency.find_by(id: payload["agency_id"])
          if a
            @current_agency = a
            Current.agency  = a
          end
        end
      end


      def current_agency
        @current_agency
      end


      # Аутентификация пользователя по access-токену
      def authenticate_user!
        render_unauthorized unless current_user
      end

      # Возвращает текущего пользователя на основе токена
      #
      # @return [User, nil]
      def current_user
        @current_user ||= begin
                            token = request.headers["Authorization"]&.split&.last
                            payload = Auth::JwtService.decode_and_verify(token && token)
                            if payload.present? && payload["type"] == "access"
                              User.find_by(id: payload["sub"])
                            else
                              nil
                            end
                          end
      end
    end
  end
end
