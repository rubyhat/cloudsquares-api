# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include ApiErrorHandling
      include Pundit::Authorization

      rescue_from Pundit::NotAuthorizedError, with: :render_pundit_forbidden

      before_action :authenticate_user!
      before_action { Current.user = current_user }


      private

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
                            payload = JwtService.decode_and_verify(token && token)
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
