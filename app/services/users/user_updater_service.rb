# frozen_string_literal: true

module Users
  # Единый сервис обновления данных пользователя.
  #
  # Сценарии:
  # - mode :self (current_user == target_user): можно править профиль (в т.ч. self-name),
  #   email, пароль (требует current_password), UI/notifications. Телефон не трогаем.
  # - mode :admin (current_user != target_user): контроллером уже авторизовано через Pundit,
  #   можно править email/роль/пароль (без current_password), а ФИО — в Contact выбранного агентства.
  #
  # Имя:
  # - по умолчанию (:auto): если :self -> пишем в UserProfile; если :admin и есть agency_ctx -> в Contact.
  # - можно явно задать name_target: :profile или :contact
  #
  # Параметры:
  #   current_user: User        — кто выполняет изменение
  #   target_user:  User        — кого меняем
  #   agency_ctx:   Agency|UUID — агентство для контактного имени (необязательно)
  #   params:       Hash        — допустимые ключи см. ниже
  #   mode:         :self|:admin|:auto
  #   name_target:  :auto|:profile|:contact
  #
  # Допустимые ключи params:
  #   :first_name, :last_name, :middle_name
  #   :timezone, :locale, :avatar_url
  #   :notification_prefs (Hash), :ui_prefs (Hash)
  #   :email, :role
  #   :password, :password_confirmation, :current_password
  #
  # Исключения ActiveRecord::RecordInvalid прокидываются наружу,
  # чтобы контроллер мог показать валидируемую модель.
  class UserUpdaterService
    Result = Struct.new(:success?, :user)

    def self.call(...)
      new(...).call
    end

    def initialize(current_user:, target_user:, agency_ctx: nil, params: {}, mode: :auto, name_target: :auto)
      @current_user = current_user
      @user         = target_user
      @agency_id    = extract_agency_id(agency_ctx)
      @params       = params.symbolize_keys
      @mode         = resolve_mode(mode)
      @name_target  = name_target
    end

    def call
      ActiveRecord::Base.transaction do
        ensure_profile!

        update_profile_fields!
        update_name!
        update_user_account!

        @user.profile.save! if @user.profile.changed?
        @user.save! if @user.changed?
      end

      Result.new(true, @user)
    end

    private

    def resolve_mode(given)
      return :self  if @current_user&.id == @user&.id
      return :admin if given == :admin
      :admin
    end

    def extract_agency_id(ctx)
      return nil if ctx.nil?
      return ctx.id if ctx.respond_to?(:id)
      ctx
    end

    def ensure_profile!
      @user.profile || @user.build_profile(timezone: "UTC", locale: I18n.default_locale.to_s)
    end

    # ----- Профильные поля (общие для всех ролей) -----
    def update_profile_fields!
      prof = @user.profile
      upd = {}

      if @params.key?(:timezone)
        upd[:timezone] = @params[:timezone]
      end
      if @params.key?(:locale)
        upd[:locale] = @params[:locale]
      end
      if @params.key?(:avatar_url)
        upd[:avatar_url] = @params[:avatar_url]
      end
      if @params.key?(:notification_prefs)
        upd[:notification_prefs] = prof.notification_prefs.to_h.deep_merge(@params[:notification_prefs].to_h)
      end
      if @params.key?(:ui_prefs)
        upd[:ui_prefs] = prof.ui_prefs.to_h.deep_merge(@params[:ui_prefs].to_h)
      end

      # "Self name" в профиле — теперь для всех ролей, НО:
      # - при mode :self (любой роли) можно менять self-name в профиле
      # - при mode :admin — профильное имя менять можно по бизнес-правилам политики (авторизация снаружи)
      %i[first_name last_name middle_name].each do |k|
        next unless @params.key?(k)
        # Имя в профиле редактируем всегда; имя в Contact — ниже, отдельным блоком
        upd[k] = @params[k]
      end

      prof.assign_attributes(upd) if upd.any?
    end

    # ----- Имя в Contact для чужих пользователей в рамках агентства -----
    def update_name!
      return unless name_params_present?

      # Если явно задано, куда писать имя — уважаем
      target = @name_target
      target = infer_name_target if target == :auto

      case target
      when :profile
        # уже присвоили в update_profile_fields!
        return
      when :contact
        ensure_agency_ctx_for_contact!
        upsert_contact_name!
      else
        # по умолчанию — ничего
        nil
      end
    end

    def infer_name_target
      # self -> профиль; admin -> contact (если есть агентство), иначе профиль
      return :profile if @mode == :self
      return :contact if @mode == :admin && @agency_id.present?
      :profile
    end

    def ensure_agency_ctx_for_contact!
      return if @agency_id.present?
      raise ActiveRecord::RecordInvalid.new(empty_contact_for_error).tap { |e|
        empty_contact_for_error.errors.add(:base, "Требуется агентский контекст для обновления ФИО в контактных данных")
      }
    end

    def empty_contact_for_error
      @empty_contact_for_error ||= Contact.new
    end

    def upsert_contact_name!
      contact = Contact.find_or_initialize_by(agency_id: @agency_id, person_id: @user.person_id)

      # Присваиваем только пришедшие поля; first_name даём дефолт, если «впервые»
      if @params.key?(:first_name)
        contact.first_name = @params[:first_name].presence || contact.first_name || "—"
      end
      if @params.key?(:last_name)
        contact.last_name = @params[:last_name]
      end
      if @params.key?(:middle_name)
        contact.middle_name = @params[:middle_name]
      end

      contact.save!
    end

    def name_params_present?
      @params.slice(:first_name, :last_name, :middle_name).values.any?(&:present?) ||
        @params.key?(:first_name) || @params.key?(:last_name) || @params.key?(:middle_name)
    end

    # ----- Учетная запись (User) -----
    def update_user_account!
      upd = {}

      upd[:email] = @params[:email] if @params.key?(:email)

      if @params[:password].present?
        if @mode == :self
          unless @user.authenticate(@params[:current_password].to_s)
            # имитируем валидацию модели User
            raise ActiveRecord::RecordInvalid.new(@user).tap { |e|
              @user.errors.add(:current_password, :invalid, message: "Неверный текущий пароль")
            }
          end
        end

        upd[:password] = @params[:password]
        upd[:password_confirmation] = @params[:password_confirmation]
      end

      # Роль меняется только в админских сценариях (контроллер уже авторизовал)
      upd[:role] = @params[:role] if @mode == :admin && @params.key?(:role)

      @user.assign_attributes(upd) if upd.any?
    end
  end
end
