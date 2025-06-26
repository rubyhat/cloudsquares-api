class ApplicationController < ActionController::API
  before_action :restrict_internal_access, if: -> { request.path.start_with?("/api/internal") }

  private

  def restrict_internal_access
    allowed_token = ENV.fetch("PHOTO_JOB_SECRET", nil)
    unless allowed_token && ActiveSupport::SecurityUtils.secure_compare(request.headers["X-Auth-Token"].to_s, allowed_token)
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end
