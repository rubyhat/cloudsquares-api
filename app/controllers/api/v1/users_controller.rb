# frozen_string_literal: true

module Api
  module V1
    class UsersController < BaseController
      before_action :set_user, only: %i[show update destroy]

      # GET /api/v1/me
      def me
        user = current_user
        return render_unauthorized unless user

        authorize user, :me?
        render json: user,
               serializer: UserSerializer,
               current_agency: Current.agency,
               prefer_profile_name: true,
               status: :ok
      end

      # PATCH /api/v1/me
      def update_me
        user = current_user
        return render_unauthorized unless user

        authorize user, :update_me?

        result = Users::UserUpdaterService.call(
          current_user: user,
          target_user:  user,
          agency_ctx:   Current.agency,
          params:       me_params,     # может включать имя, профильные поля, email, пароль(+current_password)
          mode:         :self,
          name_target:  :auto          # self -> имя в профиль
        )

        render json: result.user,
               serializer: UserSerializer,
               current_agency: Current.agency,
               prefer_profile_name: true,
               status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      end

      # GET /api/v1/users
      def index
        users = policy_scope(User)
        render json: users,
               each_serializer: UserSerializer,
               current_agency: Current.agency,
               status: :ok
      end

      # GET /api/v1/users/:id
      def show
        return render_user_deleted unless @user.is_active

        authorize @user
        render json: @user,
               serializer: UserSerializer,
               current_agency: Current.agency,
               status: :ok
      end

      # POST /api/v1/users
      # Создание нового сотрудника агентства.
      # Принимаем телефон/ФИО в params, но сохраняем их в Person/Contact.
      def create
        attrs = user_params

        # Запрещаем создавать глобальные роли
        if %w[admin admin_manager].include?(attrs[:role].to_s)
          return render_forbidden(message: "Создание admin запрещено", key: "users.admin_not_allowed")
        end

        # Быстрая проверка, может ли текущий юзер создавать новых юзеров с такой ролью
        authorize User.new(role: attrs[:role])

        return render_unauthorized unless current_user

        if current_user&.agencies&.empty?
          return render_error(
            key: "users.create_user_in_agency",
            message: "Чтобы добавить сотрудника, необходимо сначала создать Агентство",
            status: :unprocessable_entity,
            code: 422
          )
        end

        # Должно быть агентство по умолчанию
        return render_forbidden(message: "Нет агентства по умолчанию") unless @current_agency

        # if Shared::LimitChecker.exceeded?(:employees, @current_agency)
        #   return render_error(
        #     key: "users.limit_exceeded",
        #     message: "Достигнут лимит сотрудников для агентства",
        #     status: :unprocessable_entity,
        #     code: 422
        #   )
        # end

        phone = attrs[:phone].to_s
        if phone.blank?
          return render_error(
            key: "users.phone_required",
            message: "Не указан номер телефона",
            status: :unprocessable_entity,
            code: 422
          )
        end

        normalized_phone = ::Shared::PhoneNormalizer.normalize(phone)
        if normalized_phone.blank?
          return render_error(
            key: "users.phone_invalid",
            message: "Некорректный номер телефона",
            status: :unprocessable_entity,
            code: 422
          )
        end

        ActiveRecord::Base.transaction do
          # Person (глобальная личность по телефону)
          person = Person.find_or_create_by!(normalized_phone: normalized_phone)

          # Запретим создавать второго User для той же Person (уникальный индекс и явная проверка)
          if User.exists?(person_id: person.id)
            return render_error(
              key: "users.phone_already_registered",
              message: "Этот номер телефона уже зарегистрирован",
              status: :unprocessable_entity,
              code: 422
            )
          end

          # Сам User уже без телефона/ФИО
          @user = User.new(
            person: person,
            email: attrs[:email],
            password: attrs[:password],
            password_confirmation: attrs[:password_confirmation],
            role: attrs[:role],
            country_code: attrs[:country_code],
            is_active: true
          )

          authorize @user

          @user.save!

          # Привязываем к агентству + делаем дефолтным
          UserAgency.create!(
            user: @user,
            agency: @current_agency,
            is_default: true,
            status: :active
          )

          # Создаём/обновляем Contact в рамках текущего агентства
          first_name  = attrs[:first_name].presence || "—"
          last_name   = attrs[:last_name]
          middle_name = attrs[:middle_name]

          Contact.find_or_create_by!(agency_id: @current_agency.id, person_id: person.id) do |c|
            c.first_name = first_name
            c.last_name = last_name
            c.middle_name = middle_name
            c.email = attrs[:email] # агентский email можно задать таким же
            c.extra_phones = []
          end
        end

        render json: @user, status: :created
      rescue ActiveRecord::RecordInvalid
        render_validation_errors(@user)
      rescue ActiveRecord::RecordNotUnique
        render_error(
          key: "users.phone_already_registered",
          message: "Этот номер телефона уже зарегистрирован",
          status: :unprocessable_entity,
          code: 422
        )
      end

      # PATCH/PUT /api/v1/users/:id
      # Обновление учётки и/или Person/Contact (если переданы phone/ФИО).
      def update
        authorize @user

        attrs = user_params

        ActiveRecord::Base.transaction do
          # Если прилетел телефон — правим его в Person
          if attrs[:phone].present?
            pn = ::Shared::PhoneNormalizer.normalize(attrs[:phone])
            if pn.blank?
              return render_error(
                key: "users.phone_invalid",
                message: "Некорректный номер телефона",
                status: :unprocessable_entity,
                code: 422
              )
            end

            # Пытаемся обновить текущему Person телефон.
            # Если такой телефон уже занят другой Person, база не даст задвоить (уникальность).
            @user.person.update!(normalized_phone: pn)
          end

          # Остальное — через сервис
          Users::UserUpdaterService.call(
            current_user: current_user,
            target_user:  @user,
            agency_ctx:   @current_agency,     # ФИО пойдёт в Contact текущего агентства
            params:       attrs.except(:phone),
            mode:         :admin,               # т.к. редактируем чужого юзера (или себя, но Pundit уже пропустил)
            name_target:  :auto
          )
        end

        render json: @user,
               serializer: UserSerializer,
               current_agency: Current.agency,
               status: :ok

      rescue ActiveRecord::RecordInvalid => e
        # Если уникальность телефона у Person сработала через валидации:
        if e.record.is_a?(Person) && e.record.errors.added?(:normalized_phone, :taken)
          return render_error(
            key: "users.phone_already_registered",
            message: "Этот номер телефона уже зарегистрирован",
            status: :unprocessable_entity,
            code: 422
          )
        end

        # Во всех прочих случаях (Contact, User, Person с другими ошибками)
        render_validation_errors(e.record)

      rescue ActiveRecord::RecordNotUnique => e
        # Если уникальность стрельнула на уровне БД (индекс), распознаём по сообщению
        if e.message =~ /people.*normalized_phone/i
          return render_error(
            key: "users.phone_already_registered",
            message: "Этот номер телефона уже зарегистрирован",
            status: :unprocessable_entity,
            code: 422
          )
        end

        # Фолбэк: показать общую ошибку
        render_error(
          key: "validation.failed",
          message: "Ошибка валидации",
          status: :unprocessable_entity,
          code: 422
        )
      end

      # DELETE /api/v1/users/:id
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

      def set_user
        @user = User.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found(
          key: "user.not_found",
          message: "Пользователь не найден"
        )
      end

      # Личные данные для /me
      def me_params
        params.require(:user).permit(
          :first_name, :last_name, :middle_name, # self-name -> профиль
          :timezone, :locale, :avatar_url,
          :email,
          :password, :password_confirmation, :current_password,
          notification_prefs: {},
          ui_prefs: {}
        )
      end

      # Параметры для /users (агентский/админский апдейт)
      def user_params
        params.require(:user).permit(
          :phone,
          :email,
          :password, :password_confirmation,
          :first_name, :last_name, :middle_name, # -> Contact текущего агентства
          :role,
          :country_code, # оставляем, если где-то используется
          :timezone, :locale, :avatar_url,
          notification_prefs: {},
          ui_prefs: {}
        )
      end
    end
  end
end
