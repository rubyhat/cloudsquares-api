# frozen_string_literal: true

module Api
  module V1
    class UsersController < BaseController
      skip_before_action :authenticate_user!, only: %i[create show]
      before_action :set_user, only: %i[show update destroy]

      # GET /api/v1/me
      #
      # Возвращает текущего авторизованного пользователя.
      # Использует current_user, установленный в BaseController.
      def me
        authorize current_user, :me?

        render json: current_user, status: :ok
      end

      # GET /api/v1/users
      # Возвращает список пользователей, доступных по политике
      def index
        users = policy_scope(User)

        render json: users, status: :ok
      end

      # GET /api/v1/users/:id
      # Возвращает одного пользователя
      def show
        unless @user.is_active
          return render_user_deleted
        end

        authorize @user
        render json: @user, status: :ok
      end

      # POST /api/v1/users
      # Создание нового пользователя
      def create
        @user = User.new(user_params)
        authorize @user

        # Запрет на создание admin
        if @user.admin?
          return render_forbidden(message: "Создание admin запрещено", key: "users.admin_not_allowed")
        end

        if @user.save
          tokens = JwtService.generate_tokens(@user)
          TokenStorageRedis.save(user_id: @user.id, iat: tokens[:iat])

          render json: {
            user: UserSerializer.new(@user, scope: @user),
            access_token: tokens[:access_token],
            refresh_token: tokens[:refresh_token]
          }, status: :created
        else
          render_validation_errors(@user)
        end
      end

      # PATCH/PUT /api/v1/users/:id
      # Обновление пользователя
      def update
        authorize @user

        if @user.update(user_params)
          render json: @user, status: :ok
        else
          render_validation_errors(@user)
        end
      end

      # DELETE /api/v1/users/:id
      # Мягкое удаление пользователя
      def destroy
        unless @user.is_active
          return render_error(
            key: "user.delete_deleted_user",
            message: "Пользователь уже был удалён ранее",
            status: :bad_request,
            code: 400
          )
        end

        authorize @user

        if @user.update(is_active: false, deleted_at: Time.current)
          render_success(
            key: "users.deleted",
            message: "Пользователь успешно удалён (деактивирован)",
            code: 200
          )
        else
          render_validation_errors(@user)
        end
      end

      private

      # Установка пользователя по ID
      def set_user
        @user = User.find(params[:id])
        render_not_found unless @user
      end

      # Список разрешённых параметров
      #
      # @return [ActionController::Parameters]
      def user_params
        params.require(:user).permit(
          :phone,
          :email,
          :password,
          :password_confirmation,
          :first_name,
          :last_name,
          :middle_name,
          :role,
          :country_code
        )
      end
    end
  end
end
