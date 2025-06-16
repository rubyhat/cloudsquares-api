class AgencySettingSerializer < ActiveModel::Serializer
  attributes :id, :site_title, :site_description, :home_page_content,
             :contacts_page_content, :meta_keywords, :meta_description,
             :color_scheme, :logo_url, :locale, :timezone,
             :created_at, :updated_at

  # Включение всех локализованных версий
  attribute :translations

  # Возвращает все переводы мультиязычных полей
  #
  # @return [Hash]
  def translations
    I18n.available_locales.index_with do |locale|
      Mobility.with_locale(locale) do
        {
          site_title: object.site_title,
          site_description: object.site_description,
          home_page_content: object.home_page_content,
          contacts_page_content: object.contacts_page_content,
          meta_keywords: object.meta_keywords,
          meta_description: object.meta_description
        }
      end
    end
  end
end
