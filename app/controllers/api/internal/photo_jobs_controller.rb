# frozen_string_literal: true

module Api
  module Internal
    class PhotoJobsController < ApplicationController
      # Карта моделей для разных типов сущностей
      PHOTO_MODEL_MAP = {
        "property" => {
          model: PropertyPhoto,
          foreign_key: :property_id
        }
        # TODO: В будущем можно добавить: "agency" => { model: AgencyPhoto, foreign_key: :agency_id }
      }.freeze

      ##
      # POST /api/internal/photo_jobs
      #
      # Добавляет задачи в очередь на обработку фото. Ожидает массив или объект с ключами:
      # - entity_type [String]
      # - entity_id [UUID]
      # - agency_id [UUID]
      # - user_id [UUID]
      # - file_url [String] — путь к файлу в бакете
      # - is_main [Boolean] — флаг основного фото
      # - position [Integer] — позиция сортировки
      # - access [String] — 'public' или 'private'
      #
      # @return [JSON] { status: 'queued', jobs: <кол-во> }
      #
      def create
        jobs = Array.wrap(params.require(:photo_job))

        enqueued = jobs.map do |job|
          permitted_job = job.permit(
            :entity_type,
            :entity_id,
            :agency_id,
            :user_id,
            :file_url,
            :is_main,
            :position,
            :access
          )

          plain_hash = JSON.parse(permitted_job.to_json)
          PhotoWorker.perform_async(plain_hash)

          permitted_job
        end

        render json: { status: "queued", jobs: enqueued.size }, status: :accepted
      rescue ActionController::ParameterMissing => e
        render json: { error: "Missing parameters", message: e.message }, status: :unprocessable_entity
      rescue => e
        logger.error("[PhotoJobsController] Failed to enqueue job: #{e.class.name}: #{e.message}")
        render json: { error: "Internal error" }, status: :internal_server_error
      end

      ##
      # DELETE /api/internal/photo_jobs/delete
      #
      # Удаляет одну или несколько записей фотографий из БД. Используется микросервисом
      # после удаления файла из S3.
      #
      # @body_param entity_type [String] — тип сущности (например, "property")
      # @body_param entity_id [UUID]
      # @body_param file_urls [Array<String>] — список ключей файлов в бакете
      #
      # @return [JSON] { status: 'ok', deleted: [...], failed: [...] }
      #
      def delete
        entity_type = params[:entity_type]
        entity_id = params[:entity_id]
        file_urls = params[:file_urls]

        unless entity_type.present? && entity_id.present? && file_urls.is_a?(Array)
          return render json: { error: "Missing or invalid parameters" }, status: :bad_request
        end

        config = PHOTO_MODEL_MAP[entity_type]
        unless config
          return render json: { error: "Invalid entity_type" }, status: :bad_request
        end

        model_class = config[:model]
        foreign_key = config[:foreign_key]

        deleted = []
        failed  = []

        file_urls.each do |url|
          photo = model_class.find_by(foreign_key => entity_id, file_url: url)

          if photo
            # WARNING: Возможно состояние race condition, если другая задача создала фото заново
            photo.destroy
            deleted << url
          else
            logger.warn "[PhotoJobsController] Photo not found in #{model_class.name}: #{url}"
            failed << url
          end
        end

        render json: { status: "ok", deleted: deleted, failed: failed }, status: :ok
      rescue => e
        logger.error("[PhotoJobsController] Failed to delete photos: #{e.class.name}: #{e.message}")
        render json: { error: "Internal error" }, status: :internal_server_error
      end
    end
  end
end
