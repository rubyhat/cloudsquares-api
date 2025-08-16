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
        # Переопределяется в контроллерах при необходимости
        false
      end

      private

      # Достаём/кешируем текущего пользователя и ОДНОКРАТНО декодируем JWT,
      # сохраняя payload в @jwt_payload (для set_current_agency и пр.)
      def current_user
        return @current_user if defined?(@current_user)

        token   = bearer_token
        payload = Auth::JwtService.decode_and_verify(token)
        @jwt_payload = payload

        @current_user =
          if payload.present? && payload["type"] == "access"
            User.find_by(id: payload["sub"])
          else
            nil
          end
      end

      def jwt_payload
        @jwt_payload
      end

      # Выбираем контекст агентства:
      # 1) приоритет — agency_id из access-токена (важно для B2C и для явного выбора контекста на фронте)
      # 2) иначе — дефолтное агентство сотрудника (UserAgency.is_default)
      def set_current_agency
        return unless current_user

        # 1) Контекст из токена
        if jwt_payload && jwt_payload["agency_id"].present?
          if (agency = Agency.find_by(id: jwt_payload["agency_id"]))
            @current_agency = agency
            Current.agency  = agency
            return
          end
        end

        # 2) Дефолтное агентство сотрудника
        if (agency = current_user&.user_agencies&.find_by(is_default: true)&.agency)
          @current_agency = agency
          Current.agency  = agency
        end
      end

      def current_agency
        @current_agency
      end

      def bearer_token
        request.headers["Authorization"]&.split&.last
      end

      # Аутентификация пользователя по access-токену
      def authenticate_user!
        render_unauthorized unless current_user
      end
    end
  end
end
