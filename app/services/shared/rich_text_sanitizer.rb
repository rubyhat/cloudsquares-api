# frozen_string_literal: true

# Typedoc:
# @class Shared::RichTextSanitizer
# @description
#   Санитайзер для безопасного HTML из TipTap. Работает по allow-list:
#   - Разрешённые теги и атрибуты перечислены явно;
#   - Любые инлайновые стили и on* обработчики удаляются;
#   - Ссылки нормализуются: запрещаем небезопасные протоколы,
#     для target="_blank" дописываем rel="noopener noreferrer nofollow".
#
# @example
#   html = Shared::RichTextSanitizer.sanitize(params[:property][:description])
#
# @return [String] Очищенный безопасный HTML (или пустая строка, если вход пустой)
#
module Shared
  class RichTextSanitizer
    # Базовый санитайзер (из rails-html-sanitizer)
    SafeList = Rails::Html::WhiteListSanitizer.new

    # Разрешаем только используемые в TipTap блоки и инлайны (без <img>).
    ALLOWED_TAGS = %w[
      p br strong em u s code pre blockquote ul ol li h1 h2 h3 hr sup sub mark a
    ].freeze

    # Разрешённые атрибуты. style НЕ допускаем.
    # Для ссылок оставляем href/target/rel/title.
    ALLOWED_ATTRIBUTES = %w[href target rel title].freeze

    # Разрешённые протоколы в href (mailto/tel по желанию – оставлены).
    ALLOWED_PROTOCOLS = %w[http https mailto tel].freeze

    class << self
      # Очищает HTML по allow-list и нормализует ссылки.
      #
      # @param [String, nil] html Входной HTML
      # @return [String] Очищенный HTML ("" для nil/пустых входов)
      def sanitize(html)
        return "" if html.blank?

        cleaned = SafeList.sanitize(
          html.to_s,
          tags: ALLOWED_TAGS,
          attributes: ALLOWED_ATTRIBUTES,
          )

        # Пост-обработка ссылок: фильтрация протоколов, rel для _blank
        postprocess_links(cleaned)
      end

      private

      # Пробегаемся по ссылкам и:
      # 1) убираем опасные протоколы (javascript:, data:, vbscript:)
      # 2) добавляем rel для target="_blank"
      #
      # @param [String] html
      # @return [String]
      def postprocess_links(html)
        # Loofah входит транзитивно через rails-html-sanitizer
        doc = Loofah.fragment(html)

        doc.css("a").each do |a|
          href = a["href"].to_s

          # Руби URI.parse понимает и mailto/tel; некорректные ссылки — убираем href
          begin
            uri = URI.parse(href)
          rescue URI::InvalidURIError
            a.remove_attribute("href")
            next
          end

          # Протокол не в allow-list -> убираем href
          if uri.scheme && !ALLOWED_PROTOCOLS.include?(uri.scheme.downcase)
            a.remove_attribute("href")
          end

          # target="_blank" -> гарантируем rel-набор
          if a["target"].to_s.downcase == "_blank"
            rel = a["rel"].to_s.split(/\s+/)
            %w[noopener noreferrer nofollow].each { |t| rel << t unless rel.include?(t) }
            a["rel"] = rel.uniq.join(" ")
          end
        end

        # Вырезаем любые on* атрибуты, если вдруг проскочили
        doc.traverse do |node|
          next unless node.element?
          node.attribute_nodes.select { |attr| attr.name.downcase.start_with?("on") }.each(&:remove)
        end

        doc.to_html
      end
    end
  end
end
