# frozen_string_literal: true

# TODO: Этот концерн сделан при помощи GPT, нужно проверить его безопасность и работоспособность

# Универсальная пагинация и сортировка для всех index-эндпоинтов.
#
# Пагинация:
# - Читает только query string (request.query_parameters), не трогая path params.
# - per_page/page приводятся к Integer и кэпятся.
# - pages считается целочисленно.
#
# Сортировка:
# - Белый список ключей (allowed), либо алиасы (Hash).
# - Поддержка одного поля (?sort_by=&sort_dir=) и мульти (?sort=created_at,-phone).
# - Для Postgres опционально NULLS LAST (через Arel.sql) — безопасно, т.к. только whitelist.
#
module PaginationConcern
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE     = 100

  included do
    private

    # @return [Hash{Symbol=>Integer}] { per_page:, page: }
    def pagination_params
      qp = request.query_parameters
      per_page = qp.fetch("per_page", DEFAULT_PER_PAGE).to_i
      page     = qp.fetch("page", 1).to_i

      per_page = DEFAULT_PER_PAGE if per_page <= 0
      per_page = MAX_PER_PAGE if per_page > MAX_PER_PAGE
      page = 1 if page <= 0

      { per_page:, page: }
    end

    # @param scope [ActiveRecord::Relation]
    # @param order [Array, Hash, Arel::Nodes::SqlLiteral, nil]
    # @return [Hash] { records:, total:, pages:, per_page:, page: }
    def paginate(scope, order: nil)
      scope = scope.order(order) if order.present?

      total = scope.count
      pp = pagination_params

      # Жёстко приводим к Integer на случай переопределений где‑то «снаружи»
      per_page = pp[:per_page].to_i
      page     = pp[:page].to_i

      pages = per_page.zero? ? 0 : ((total + per_page - 1) / per_page)
      records = scope.offset((page - 1) * per_page).limit(per_page)

      { records:, total:, pages:, per_page:, page: }
    end

    def render_paginated(scope, serializer:, order: nil)
      result = paginate(scope, order:)
      data = ActiveModelSerializers::SerializableResource.new(
        result[:records],
        each_serializer: serializer
      ).as_json

      render json: {
        data: data,
        pages: result[:pages],
        total: result[:total]
      }
    end

    # ---- СОРТИРОВКА ----

    def safe_sort(allowed:, default: nil, nulls_last: false)
      qp = request.query_parameters

      if qp["sort"].present?
        return build_multi_sort(qp["sort"], allowed:, nulls_last:)
      end

      col = qp["sort_by"].to_s
      return normalize_default(default) if col.blank?

      dir = qp["sort_dir"].to_s.downcase == "desc" ? :desc : :asc
      build_single_sort(col:, dir:, allowed:, nulls_last:) || normalize_default(default)
    end

    def normalize_allowed(allowed)
      case allowed
      when Hash  then allowed
      when Array then allowed.index_with { |k| k }
      else {}
      end
    end

    def normalize_default(default)
      case default
      when Array
        col, dir = default
        { col => (dir&.to_sym || :asc) }
      else
        default
      end
    end

    def build_single_sort(col:, dir:, allowed:, nulls_last:)
      map = normalize_allowed(allowed)
      target = map[col]
      return nil unless target
      return target.call(dir) if target.is_a?(Proc)

      return arel_order(target.to_s, dir, nulls_last:) if nulls_last

      if target.to_s.include?(".")
        Arel.sql(%(#{target} #{dir.to_s.upcase}))
      else
        { target.to_sym => dir }
      end
    end

    def build_multi_sort(raw, allowed:, nulls_last:)
      map = normalize_allowed(allowed)
      parts = raw.to_s.split(",").map(&:strip).reject(&:blank?)
      return nil if parts.empty?

      clauses = parts.filter_map do |item|
        dir = item.start_with?("-") ? :desc : :asc
        key = item.delete_prefix("-")
        target = map[key]
        next unless target

        if target.is_a?(Proc)
          target.call(dir)
        else
          nulls_last ? arel_order(target.to_s, dir, nulls_last: true) :
            (target.to_s.include?(".") ? Arel.sql(%(#{target} #{dir.to_s.upcase})) :
               { target.to_sym => dir })
        end
      end

      return nil if clauses.empty?
      clauses
    end

    def arel_order(column, dir, nulls_last:)
      raise ArgumentError, "dir must be :asc or :desc" unless %i[asc desc].include?(dir)
      Arel.sql(%(#{column} #{dir.to_s.upcase}#{nulls_last ? " NULLS LAST" : ""}))
    end
  end
end

