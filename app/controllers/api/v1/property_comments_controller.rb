# frozen_string_literal: true

module Api
  module V1
    class PropertyCommentsController < BaseController
      before_action :authenticate_user!
      before_action :set_property
      before_action :set_comment, only: %i[update destroy]
      after_action :verify_authorized

      # GET /api/v1/properties/:property_id/comments
      def index
        authorize PropertyComment
        comments = @property.property_comments.active.includes(:user).order(created_at: :asc)
        render json: comments, each_serializer: PropertyCommentSerializer
      end

      # POST /api/v1/properties/:property_id/comments
      def create
        comment = @property.property_comments.build(comment_params.merge(user: current_user))
        authorize comment

        if comment.save
          render json: comment, serializer: PropertyCommentSerializer, status: :created
        else
          render_validation_errors(comment)
        end
      end

      # PATCH /api/v1/properties/:property_id/comments/:id
      def update
        authorize @comment

        if @comment.update(comment_params)
          render json: @comment, serializer: PropertyCommentSerializer
        else
          render_validation_errors(@comment)
        end
      end

      # DELETE /api/v1/properties/:property_id/comments/:id
      def destroy
        authorize @comment

        if @comment.is_deleted?
          return render_error(
            key: "property_comments.already_deleted",
            message: "Комментарий уже удалён",
            status: :unprocessable_entity,
            code: 422
          )
        end

        if @comment.soft_delete!
          render_success(
            key: "property_comments.deleted",
            message: "Комментарий успешно удалён",
            code: 200
          )
        else
          render_validation_errors(@comment)
        end
      end

      private

      def set_property
        @property = Property.find(params[:property_id])
      rescue ActiveRecord::RecordNotFound
        render_not_found("Объект недвижимости не найден", "properties.not_found")
      end

      def set_comment
        @comment = @property.property_comments.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found("Комментарий не найден", "property_comments.not_found")
      end

      def comment_params
        params.require(:property_comment).permit(:body)
      end
    end
  end
end
