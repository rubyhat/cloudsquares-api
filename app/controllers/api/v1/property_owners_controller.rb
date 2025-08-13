# frozen_string_literal: true

# Контроллер владельцев объектов недвижимости.
# Хранение контактных данных переведено на Contact/Person.
#
# Потоки данных:
# - create: phone → Person (upsert); ФИО/email → Contact(Current.agency); затем создаём PropertyOwner(contact_id: …)
# - update: если приходит phone — апдейтим Person; ФИО/email — апдейтим Contact; роль/notes/user_id — в PropertyOwner
#
# Сортировка:
# - "phone" теперь сортируется по people.normalized_phone через JOIN (contact → person)
#
# Безопасность/валидации:
# - Проверяем лимит владельцев на объект (<= 5)
# - Все операции внутри транзакций, аккуратная обработка ошибок
module Api
  module V1
    class PropertyOwnersController < BaseController
      before_action :authenticate_user!
      before_action :set_property, only: %i[index show create update destroy]
      before_action :set_owner,    only: %i[show update destroy]
      after_action :verify_authorized

      # GET /api/v1/properties/:property_id/owners
      #
      # Параметры:
      # - per_page: Integer (default 20, max 100)
      # - page:     Integer (default 1)
      # - sort_by:  created_at | role | phone
      # - sort_dir: asc | desc (default desc для created_at)
      def index
        authorize PropertyOwner

        scope = PropertyOwner
                  .active
                  .joins(:property)
                  .where(properties: { agency_id: Current.agency.id, id: @property.id })
                  .includes(:property, contact: :person)

        order = safe_sort(
          allowed: {
            "created_at" => "property_owners.created_at",
            "role"       => "property_owners.role",
            # сортировка по телефону теперь через people.normalized_phone
            "phone"      => "people.normalized_phone"
          },
          default: { "property_owners.created_at" => :desc },
          nulls_last: false
        )

        render_paginated(scope.joins(contact: :person), serializer: PropertyOwnerSerializer, order:)
      end

      # GET /api/v1/properties/:property_id/owners/:id
      def show
        authorize @owner
        render json: @owner, serializer: PropertyOwnerSerializer
      end

      # POST /api/v1/properties/:property_id/owners
      #
      # Тело запроса:
      # {
      #   "property_owner": {
      #     "phone": "77001234567",          # -> Person.normalized_phone
      #     "first_name": "Иван",            # -> Contact.first_name (в рамках агентства объекта)
      #     "last_name": "Иванов",           # -> Contact.last_name
      #     "middle_name": "Иванович",       # -> Contact.middle_name
      #     "email": "example@x.y",          # -> Contact.email
      #     "user_id": "...",                # -> PropertyOwner.user_id (optional)
      #     "role": "primary",               # -> PropertyOwner.role
      #     "notes": "Комментарий"           # -> PropertyOwner.notes
      #   }
      # }
      def create
        authorize PropertyOwner

        if @property.property_owners.active.count >= 5
          return render_error(
            key: "property_owners.limit_exceeded",
            message: "Достигнут лимит в 5 владельцев для одного объекта",
            status: :unprocessable_entity,
            code: 422
          )
        end

        cp = owner_params

        phone = cp[:phone].to_s
        if phone.blank?
          return render_error(
            key: "property_owners.phone_required",
            message: "Не указан номер телефона",
            status: :unprocessable_entity,
            code: 422
          )
        end

        normalized = ::Shared::PhoneNormalizer.normalize(phone)
        if normalized.blank?
          return render_error(
            key: "property_owners.phone_invalid",
            message: "Некорректный номер телефона",
            status: :unprocessable_entity,
            code: 422
          )
        end

        ActiveRecord::Base.transaction do
          # 1) Person по телефону
          person = Person.find_or_create_by!(normalized_phone: normalized)

          # 2) Contact внутри агентства объекта
          contact = Contact.find_or_initialize_by(agency_id: @property.agency_id, person_id: person.id)
          contact.first_name  = cp[:first_name].presence || contact.first_name || "—"
          contact.last_name   = cp.key?(:last_name)   ? cp[:last_name]   : contact.last_name
          contact.middle_name = cp.key?(:middle_name) ? cp[:middle_name] : contact.middle_name
          contact.email       = cp.key?(:email)       ? cp[:email]       : contact.email
          contact.save!

          # 3) PropertyOwner
          owner = @property.property_owners.build(
            contact_id: contact.id,
            user_id:    cp[:user_id],
            role:       cp[:role] || "primary",
            notes:      cp[:notes],
            is_deleted: false
          )

          authorize owner

          if owner.save
            render json: owner, serializer: PropertyOwnerSerializer, status: :created
          else
            render_validation_errors(owner)
          end
        end
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      rescue ActiveRecord::RecordNotUnique
        render_error(
          key: "property_owners.conflict",
          message: "Невозможно создать владельца: конфликт уникальности данных",
          status: :unprocessable_entity,
          code: 422
        )
      end

      # PATCH /api/v1/properties/:property_id/owners/:id
      #
      # Обновление:
      # - phone → обновляем person.normalized_phone
      # - ФИО/email → обновляем contact
      # - role/notes/user_id → обновляем owner
      def update
        authorize @owner
        cp = owner_params
        updated = false

        ActiveRecord::Base.transaction do
          # Обновление телефона
          if cp[:phone].present?
            pn = ::Shared::PhoneNormalizer.normalize(cp[:phone])
            if pn.blank?
              return render_error(
                key: "property_owners.phone_invalid",
                message: "Некорректный номер телефона",
                status: :unprocessable_entity,
                code: 422
              )
            end
            @owner.person.update!(normalized_phone: pn)
            updated = true
          end

          # Обновление ФИО/email в Contact
          if (%i[first_name last_name middle_name email] & cp.keys).any?
            contact = @owner.contact
            contact.first_name  = cp[:first_name].presence || contact.first_name if cp.key?(:first_name)
            contact.last_name   = cp[:last_name]   if cp.key?(:last_name)
            contact.middle_name = cp[:middle_name] if cp.key?(:middle_name)
            contact.email       = cp[:email]       if cp.key?(:email)
            contact.save!
            updated = true
          end

          # Обновление полей самого PropertyOwner
          po_updatable = {}
          po_updatable[:role]    = cp[:role]    if cp.key?(:role)
          po_updatable[:notes]   = cp[:notes]   if cp.key?(:notes)
          po_updatable[:user_id] = cp[:user_id] if cp.key?(:user_id)

          if po_updatable.any?
            unless @owner.update(po_updatable)
              return render_validation_errors(@owner)
            end
            updated = true
          end
        end

        if updated
          render json: @owner, serializer: PropertyOwnerSerializer, status: :ok
        else
          render_success(
            key: "property_owners.nothing_to_update",
            message: "Нет данных для обновления",
            code: 200
          )
        end
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      rescue ActiveRecord::RecordNotUnique
        render_error(
          key: "property_owners.phone_conflict",
          message: "Этот номер телефона уже используется другой персоной",
          status: :unprocessable_entity,
          code: 422
        )
      end

      # DELETE /api/v1/properties/:property_id/owners/:id
      def destroy
        authorize @owner

        if @owner.is_deleted?
          return render_error(
            key: "property_owners.already_deleted",
            message: "Владелец уже деактивирован",
            status: :unprocessable_entity,
            code: 422
          )
        end

        if @owner.soft_delete!
          render_success(
            key: "property_owners.deleted",
            message: "Владелец недвижимости деактивирован",
            code: 200
          )
        else
          render_validation_errors(@owner)
        end
      end

      private

      # Поиск объекта недвижимости по :property_id
      def set_property
        @property = Property.find(params[:property_id])
      rescue ActiveRecord::RecordNotFound
        render_not_found("Объект недвижимости не найден", "properties.not_found")
      end

      # Поиск владельца в рамках конкретного объекта
      def set_owner
        @owner = @property.property_owners
                          .includes(:property, contact: :person)
                          .find_by(id: params[:id])
        render_not_found("Владелец не найден", "property_owners.not_found") unless @owner
      end

      # Разрешённые параметры.
      # ВНИМАНИЕ: first_name/last_name/middle_name/phone/email — НЕ поля PropertyOwner.
      # Они применяются к Contact/Person.
      def owner_params
        params.require(:property_owner).permit(
          :first_name, :last_name, :middle_name,  # -> Contact
          :phone, :email,                         # -> Person / Contact.email
          :notes, :user_id, :role                 # -> PropertyOwner
        )
      end
    end
  end
end
