# frozen_string_literal: true

module Api
  module V1
    # Контроллер для управления контактами в рамках агентства (B2B-админка).
    #
    # Потоки:
    # - CREATE: params[:phone] -> upsert Person(normalized_phone), затем upsert Contact(agency_id, person_id)
    # - UPDATE: опционально меняем телефон -> person.normalized_phone; остальное в самой Contact
    # - INDEX: фильтрация/сортировка, поиск по телефону делается через JOIN к people.normalized_phone
    #
    # Требования безопасности:
    # - Все операции требуют аутентификации и наличия Current.agency.
    # - Политика запрещает кросс-tenant доступ.
    class ContactsController < BaseController
      before_action :authenticate_user!
      before_action :ensure_agency!
      before_action :set_contact, only: %i[show update destroy]
      after_action :verify_authorized

      # GET /api/v1/contacts
      #
      # Параметры:
      # - q: строка поиска по имени/почте/телефону
      # - phone: точный телефон (любой формат; нормализуется)
      # - per_page, page: пагинация
      # - sort_by: created_at | first_name | last_name | phone
      # - sort_dir: asc | desc
      #
      # @return [JSON] список контактов текущего агентства
      def index
        authorize Contact

        scope = policy_scope(Contact)
                  .where(agency_id: Current.agency.id)
                  .left_joins(:person) # важное: делаем JOIN заранее (и для фильтров, и для сортировки)

        # Точный поиск по телефону (нормализуем)
        if params[:phone].present?
          normalized = ::Shared::PhoneNormalizer.normalize(params[:phone].to_s)
          scope = scope.where(people: { normalized_phone: normalized }) if normalized.present?
        end

        # Поиск по имени/почте/телефону (простая версия)
        if params[:q].present?
          q = params[:q].to_s.strip
          digits = q.gsub(/\D+/, "")
          scope = scope.where(
            "contacts.first_name ILIKE :q OR contacts.last_name ILIKE :q OR contacts.middle_name ILIKE :q OR contacts.email ILIKE :q OR people.normalized_phone LIKE :p",
            q: "%#{q}%",
            p: "%#{digits}%"
          )
        end

        # Сортировка: phone идёт по people.normalized_phone
        order_sql = safe_sort(
          allowed: {
            "created_at" => "contacts.created_at",
            "first_name" => "contacts.first_name",
            "last_name"  => "contacts.last_name",
            "phone"      => "people.normalized_phone"
          },
          default: { "contacts.created_at" => :desc },
          nulls_last: false
        )

        scope = scope.order(order_sql)
        render_paginated(scope, serializer: ContactSerializer)
      end


      # GET /api/v1/contacts/:id
      #
      # @return [JSON] один контакт
      def show
        authorize @contact
        render json: @contact, serializer: ContactSerializer, status: :ok
      end

      # POST /api/v1/contacts
      #
      # Вход:
      # {
      #   "contact": {
      #     "phone": "77001234567",          # -> Person.normalized_phone (обязательно)
      #     "first_name": "Иван",
      #     "last_name": "Иванов",
      #     "middle_name": "Иванович",
      #     "email": "ivan@example.com",
      #     "extra_phones": ["77001112233"], # нормализуются
      #     "notes": "заметки менеджера"
      #   }
      # }
      #
      # @return [JSON] созданный/найденный контакт (idempotent по (agency_id, person_id))
      def create
        authorize Contact

        cp = contact_params
        phone = cp[:phone].to_s

        if phone.blank?
          return render_error(
            key: "contacts.phone_required",
            message: "Не указан номер телефона",
            status: :unprocessable_entity,
            code: 422
          )
        end

        normalized = ::Shared::PhoneNormalizer.normalize(phone)
        if normalized.blank?
          return render_error(
            key: "contacts.phone_invalid",
            message: "Некорректный номер телефона",
            status: :unprocessable_entity,
            code: 422
          )
        end

        ActiveRecord::Base.transaction do
          # 1) upsert Person
          person = Person.find_or_create_by!(normalized_phone: normalized)

          # 2) upsert Contact (уникально в рамках агентства)
          contact = Contact.find_or_initialize_by(agency_id: Current.agency.id, person_id: person.id)
          contact.first_name  = cp[:first_name].presence || contact.first_name || "—"
          contact.last_name   = cp[:last_name]   if cp.key?(:last_name)
          contact.middle_name = cp[:middle_name] if cp.key?(:middle_name)
          contact.email       = cp[:email]       if cp.key?(:email)
          if cp.key?(:extra_phones)
            contact.extra_phones = Array(cp[:extra_phones]).map { |p| ::Shared::PhoneNormalizer.normalize(p) }.reject(&:blank?)
          end
          contact.notes = cp[:notes] if cp.key?(:notes)
          contact.is_deleted = false if contact.has_attribute?(:is_deleted)
          contact.save!

          render json: contact, serializer: ContactSerializer, status: :created
        end
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      rescue ActiveRecord::RecordNotUnique
        # На случай гонки: параллельный upsert того же контакта
        contact = Contact.find_by(agency_id: Current.agency.id, person_id: Person.find_by(normalized_phone: normalized)&.id)
        if contact
          render json: contact, serializer: ContactSerializer, status: :ok
        else
          render_error(
            key: "contacts.conflict",
            message: "Конфликт уникальности при создании контакта",
            status: :unprocessable_entity,
            code: 422
          )
        end
      end

      # PATCH /api/v1/contacts/:id
      #
      # Допускаем смену телефона — это апдейт Person.normalized_phone.
      # Остальные поля редактируются в Contact.
      def update
        authorize @contact
        cp = contact_params
        updated = false

        ActiveRecord::Base.transaction do
          # Обновление телефона (Person)
          if cp[:phone].present?
            pn = ::Shared::PhoneNormalizer.normalize(cp[:phone])
            if pn.blank?
              return render_error(
                key: "contacts.phone_invalid",
                message: "Некорректный номер телефона",
                status: :unprocessable_entity,
                code: 422
              )
            end
            @contact.person.update!(normalized_phone: pn)
            updated = true
          end

          # Обновление полей Contact
          updatable = {}
          updatable[:first_name]  = cp[:first_name].presence if cp.key?(:first_name)
          updatable[:last_name]   = cp[:last_name]          if cp.key?(:last_name)
          updatable[:middle_name] = cp[:middle_name]        if cp.key?(:middle_name)
          updatable[:email]       = cp[:email]              if cp.key?(:email)
          updatable[:notes]       = cp[:notes]              if cp.key?(:notes)
          if cp.key?(:extra_phones)
            updatable[:extra_phones] = Array(cp[:extra_phones]).map { |p| ::Shared::PhoneNormalizer.normalize(p) }.reject(&:blank?)
          end

          if updatable.any?
            @contact.update!(updatable)
            updated = true
          end
        end

        if updated
          render json: @contact, serializer: ContactSerializer, status: :ok
        else
          render_success(
            key: "contacts.nothing_to_update",
            message: "Нет данных для обновления",
            code: 200
          )
        end
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      rescue ActiveRecord::RecordNotUnique
        render_error(
          key: "contacts.phone_conflict",
          message: "Этот номер телефона уже используется другой персоной",
          status: :unprocessable_entity,
          code: 422
        )
      end

      # DELETE /api/v1/contacts/:id
      #
      # Мягкое удаление контакта.
      def destroy
        authorize @contact

        if @contact.is_deleted?
          return render_error(
            key: "contacts.already_deleted",
            message: "Контакт уже деактивирован",
            status: :unprocessable_entity,
            code: 422
          )
        end

        if @contact.update(is_deleted: true, deleted_at: Time.zone.now)
          render_success(
            key: "contacts.deleted",
            message: "Контакт деактивирован",
            code: 200
          )
        else
          render_validation_errors(@contact)
        end
      end

      private

      # Проверяем наличие текущего агентства
      #
      # @return [void]
      def ensure_agency!
        render_forbidden(message: "Нет агентства по умолчанию") unless Current.agency
      end

      # Загрузка контакта по ID в рамках текущего агентства
      #
      # @return [void]
      def set_contact
        @contact = Contact
                     .where(agency_id: Current.agency.id)
                     .includes(:person)
                     .find_by(id: params[:id])

        render_not_found("Контакт не найден", "contacts.not_found") unless @contact
      end

      # Разрешённые параметры
      #
      # @return [ActionController::Parameters]
      def contact_params
        params.require(:contact).permit(
          :phone,        # -> person.normalized_phone
          :first_name,
          :last_name,
          :middle_name,
          :email,
          :notes,
          extra_phones: []
        )
      end
    end
  end
end
