# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include ApiErrorHandling
      include Pundit::Authorization

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

        agency = current_user&.user_agencies&.find_by(is_default: true)&.agency
        if agency.present?
          @current_agency = agency
          Current.agency = agency
        # TODO: если раскомментировать код, то не создается агентство, пофиксить
        # else
        #   render_error(
        #     key: "auth.no_agency",
        #     message: "Пользователь не привязан ни к одному агентству",
        #     status: :forbidden,
        #     code: 403
        #   )
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
