# frozen_string_literal: true

module Api
  module V1
    class UsersController < BaseController
      before_action :set_user, only: %i[show update destroy]

      # GET /api/v1/me
      #
      # Возвращает текущего авторизованного пользователя.
      # Использует current_user, установленный в BaseController.
      def me
        user = current_user
        return render_unauthorized unless user
        authorize user, :me?

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

      # Создание нового пользователя
      # POST /api/v1/users
      def create
        @user = User.new(user_params)

        if @user.role == "admin" || @user.role == "admin_manager"
          return render_forbidden(message: "Создание admin запрещено", key: "users.admin_not_allowed")
        end

        authorize @user
        return render_unauthorized unless current_user

        if current_user&.agencies&.empty?
          return render_error(
          key: "users.create_user_in_agency",
          message: "Чтобы добавить сотрудника, необходимо сначала создать Агентство",
          status: :unprocessable_entity,
          code: 422
        )
        end

        # Ограничим создание только в рамках агентства текущего пользователя
        return render_forbidden(message: "Нет агентства по умолчанию") unless @current_agency

        # ⚠️ TODO: временная проверка лимита (захардкожено 5 сотрудников)
        if @current_agency.users.count >= 5
          return render_error(
            key: "users.limit_exceeded",
            message: "Достигнут лимит сотрудников для агентства",
            status: :unprocessable_entity,
            code: 422
          )
        end

        # Сохраняем пользователя и привязываем к агентству
        ActiveRecord::Base.transaction do
          @user.save!

          UserAgency.create!(
            user: @user,
            agency: @current_agency,
            is_default: true,  # У нового пользователя — всегда по умолчанию
            status: :active
          )
        end

        render json: @user, status: :created

      rescue ActiveRecord::RecordInvalid
        render_validation_errors(@user)
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

        if @user.update(is_active: false, deleted_at: Time.zone.now)
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
      # Определение Агентства пользователя
      def current_agency_for_user(user)
        user&.user_agencies&.find_by(is_default: true)&.agency
      end

      # Установка пользователя по ID
      def set_user
        @user = User.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found(
          key: "user.not_found",
          message: "GПользователь не найден"
        ) unless @user
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
