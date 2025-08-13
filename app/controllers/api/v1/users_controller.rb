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
        render json: user, status: :ok
      end

      # GET /api/v1/users
      def index
        users = policy_scope(User)
        render json: users, status: :ok
      end

      # GET /api/v1/users/:id
      def show
        return render_user_deleted unless @user.is_active

        authorize @user
        render json: @user, status: :ok
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

        authorize User
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

        if Shared::LimitChecker.exceeded?(:employees, @current_agency)
          return render_error(
            key: "users.limit_exceeded",
            message: "Достигнут лимит сотрудников для агентства",
            status: :unprocessable_entity,
            code: 422
          )
        end

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
        updated = false

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
            updated = true
          end

          # Если прилетели ФИО — правим/создаём Contact в рамках текущего агентства
          if attrs.slice(:first_name, :last_name, :middle_name).values.any?(&:present?) && @current_agency
            contact = Contact.find_or_create_by!(agency_id: @current_agency.id, person_id: @user.person_id)
            contact.first_name  = attrs[:first_name].presence || contact.first_name || "—"
            contact.last_name   = attrs[:last_name]   if attrs.key?(:last_name)
            contact.middle_name = attrs[:middle_name] if attrs.key?(:middle_name)
            contact.save!
            updated = true
          end

          # Обновляем собственно User-поля, если пришли
          user_updatable = {}
          user_updatable[:email] = attrs[:email] if attrs.key?(:email)
          user_updatable[:role] = attrs[:role] if attrs.key?(:role)
          user_updatable[:country_code] = attrs[:country_code] if attrs.key?(:country_code)
          if attrs[:password].present?
            user_updatable[:password] = attrs[:password]
            user_updatable[:password_confirmation] = attrs[:password_confirmation]
          end

          if user_updatable.any?
            unless @user.update(user_updatable)
              return render_validation_errors(@user)
            end
            updated = true
          end
        end

        if updated
          render json: @user, status: :ok
        else
          render_success(
            key: "users.nothing_to_update",
            message: "Нет данных для обновления",
            code: 200
          )
        end
      rescue ActiveRecord::RecordInvalid => e
        # В т.ч. при конфликте уникальности телефона в people
        if e.record.is_a?(Person) && e.record.errors.added?(:normalized_phone, :taken)
          return render_error(
            key: "users.phone_already_registered",
            message: "Этот номер телефона уже зарегистрирован",
            status: :unprocessable_entity,
            code: 422
          )
        end
        render_validation_errors(@user)
      rescue ActiveRecord::RecordNotUnique
        render_error(
          key: "users.phone_already_registered",
          message: "Этот номер телефона уже зарегистрирован",
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

      # Определение Агентства пользователя (оставляем для обратной совместимости)
      def current_agency_for_user(user)
        user&.user_agencies&.find_by(is_default: true)&.agency
      end

      def set_user
        @user = User.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found(
          key: "user.not_found",
          message: "Пользователь не найден"
        )
      end

      # Разрешённые параметры. phone + ФИО — это для Person/Contact.
      def user_params
        params.require(:user).permit(
          :phone,                    # -> Person.normalized_phone
          :email,                    # хранится в users (учётный), агентский email — в Contact
          :password,
          :password_confirmation,
          :first_name, :last_name, :middle_name, # -> Contact внутри текущего агентства
          :role,
          :country_code
        )
      end
    end
  end
end
