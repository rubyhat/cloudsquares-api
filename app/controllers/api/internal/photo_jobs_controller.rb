# frozen_string_literal: true

module Api
  module Internal
    class PhotoJobsController < ApplicationController
      # POST /api/internal/photo_jobs
      def create
        # Валидация параметров
        permitted = params.require(:photo_job).permit(
          :entity_type, :entity_id, :agency_id, :user_id,
          :file_url, :is_main, :position, :access
        )

        PhotoWorker.perform_async(JSON.parse(permitted.to_json))

        render json: { status: "queued" }, status: :accepted
      rescue ActionController::ParameterMissing => e
        render json: { error: "Missing parameters", message: e.message }, status: :unprocessable_entity
      rescue => e
        logger.error("[PhotoJobsController] Failed to enqueue job: #{e.message}")
        render json: { error: "Internal error" }, status: :internal_server_error
      end
    end
  end
end
