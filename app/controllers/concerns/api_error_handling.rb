# frozen_string_literal: true

=begin
  TODO: locale в заголовке (например, Accept-Language: ru)
  message полностью убрать (оставить только key)
  поддержку meta (например, fields: ['email'])
  категорию ошибок: validation, auth, business, server
=end


module ApiErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from JWT::DecodeError, with: :render_invalid_token
    rescue_from JWT::ExpiredSignature, with: :render_expired_token
    rescue_from ActiveRecord::RecordNotUnique, with: :render_record_not_unique

    # Важно: перехватываем валидации, упавшие на уровне ассоциаций/колбэков,
    # чтобы вернуть корректный JSON с подробностями.
    rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

    # Базовая обработка ошибок 500+ todo: надо протестить
    rescue_from StandardError do |exception|
      logger.error "[#{exception.class}] #{exception.message}"
      logger.error exception.backtrace.join("\n") if Rails.env.development? || Rails.env.test?

      render json: {
        status: 500,
        error: "Internal Server Error",
        message: exception.message,
        class: exception.class.name
      }, status: :internal_server_error
    end
  end

  private


  # Унифицированный рендер ошибок валидации для поднятых исключений
  #
  # @param exception [ActiveRecord::RecordInvalid]
  # @return [void]
  def render_record_invalid(exception)
    resource = exception.record
    render json: {
      error: {
        key: "validation.failed",
        message: "Ошибка валидации",
        code: 422,
        status: :unprocessable_entity,
        details: extract_full_errors(resource)
      }
    }, status: :unprocessable_entity
  end

  # Обработка уникальности на уровне базы (например, индекс tax_id)
  def render_record_not_unique(exception = nil)
    constraint = extract_constraint_from_exception(exception)
    message = friendly_message_for_constraint(constraint)

    render_error(
      key: "validation.#{constraint}",
      message: message || "Дубликат значения нарушает уникальность",
      status: :unprocessable_entity,
      code: 422
    )
  end


  # Парсим constraint из текста PG ошибки
  def extract_constraint_from_exception(exception)
    return nil unless exception&.message

    match = exception.message.match(/unique constraint \"(?<name>[^\"]+)\"/)
    match[:name] if match
  end

  # Возвращаем пользовательское сообщение по имени constraint'а
  def friendly_message_for_constraint(constraint)
    case constraint
    when "index_legal_profiles_on_tax_id"
      "Такой налоговый номер уже используется"
    when "index_users_on_email"
      "Этот email уже зарегистрирован"
    when "index_users_on_phone"
      "Этот номер телефона уже используется"
    else
      nil
    end
  end



  # Обработка ошибки Pundit::NotAuthorizedError
  def render_unauthorized(message = "Необходимо войти в аккаунт", key = "auth.unauthorized")
    render_error(key: key, message: message, status: :unauthorized, code: 401)
  end

  # Ресурс не найден
  def render_not_found(message = "Ресурс не найден", key = "common.not_found")
    render_error(key: key, message: message, status: :not_found, code: 404)
  end

  # Невалидный JWT токен
  def render_invalid_token
    render_error(
      key: "auth.invalid_token",
      message: "Invalid token",
      status: :unauthorized,
      code: 401
    )
  end

  # Истёкший JWT токен
  def render_expired_token
    render_error(
      key: "auth.token_expired",
      message: "Token expired",
      status: :unauthorized,
      code: 401
    )
  end

  def render_pundit_forbidden(exception)
    query_name = exception.query.to_s
    record_class = exception.record.is_a?(Class) ? exception.record : exception.record.class
    record_name = record_class.name.demodulize.underscore

    # todo: текст ошибок временный, в будущем отправлять ключи, а на фронте отображать ошибки на нужных языках
    # Карта действий → человекочитаемые фразы
    query_map = {
      "index?" => "просмотр списка",
      "show?" => "просмотр",
      "create?" => "создание",
      "update?" => "редактирование",
      "destroy?" => "удаление",
      "unverify?" => "отключение верификации"
    }

    # Карта моделей → человекочитаемые ресурсы
    record_map = {
      "legal_profile" => "юридическим профилям",
      "seller_profile" => "профилю продавца",
      "shop" => "магазину",
      "user" => "пользователю",
      "product" => "товару",
      "order" => "заказу"
    }

    action_text = query_map.fetch(query_name, "действию")
    resource_text = record_map.fetch(record_name, "ресурса")

    message = "Нет прав на #{action_text} #{resource_text}"

    render_forbidden(message: message, key: "auth.pundit.forbidden")
  end

  # Ошибка авторизации (доступ запрещён)
  def render_forbidden(message: "Access denied", key: "auth.forbidden")
    render_error(key: key, message: message, status: :forbidden, code: 403)
  end

  # Пользователь ранее удалён (is_active: false)
  def render_user_deleted
    render json: {
      error: {
        key: "user.deleted",
        message: "Пользователь удалил свой аккаунт",
        code: 410,
        status: "gone"
      }
    }, status: :gone
  end

  # Универсальная точка возврата ошибок
  def render_error(key:, message:, status:, code:)
    render json: {
      error: {
        key: key,
        message: message,
        code: code,
        status: status
      }
    }, status: status
  end

  # Универсальный успех
  def render_success(key:, message:, code: 200)
    render json: {
      success: {
        key: key,
        message: message,
        code: code,
        status: :ok
      }
    }, status: :ok
  end

  # Ошибки валидации ActiveModel/ActiveRecord
  def render_validation_errors(resource)
    render json: {
      error: {
        key: "validation.failed",
        message: "Ошибка валидации",
        code: 422,
        status: :unprocessable_entity,
        details: extract_full_errors(resource)
      }
    }, status: :unprocessable_entity
  end

  # Глубокий сбор ошибок: собственные + has_one/has_many (включая nested_attributes)
  #
  # @param resource [ActiveRecord::Base]
  # @return [Hash] хэш с сообщениями, включая дочерние записи
  def extract_full_errors(resource)
    # Собственные ошибки ресурса
    all = resource.errors.to_hash(true)

    # Пробегаемся по ассоциациям и добавляем их ошибки в details.
    resource.class.reflect_on_all_associations.each do |assoc|
      next unless %i[has_one has_many].include?(assoc.macro)

      associated = safe_associated(resource, assoc.name)
      next if associated.blank?

      if associated.is_a?(Enumerable)
        associated.each_with_index do |rec, idx|
          next if rec.errors.empty?
          all["#{assoc.name}[#{idx}]"] = rec.errors.to_hash(true)
        end
      else
        all[assoc.name] = associated.errors.to_hash(true) unless associated.errors.empty?
      end
    end

    all
  end

  # Безопасно получить ассоциированные записи без выбрасывания ошибок
  #
  # @param resource [ActiveRecord::Base]
  # @param name [Symbol]
  # @return [ActiveRecord::Base, Array<ActiveRecord::Base>, nil]
  def safe_associated(resource, name)
    resource.public_send(name)
  rescue StandardError
    nil
  end
end
