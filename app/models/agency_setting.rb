class AgencySetting < ApplicationRecord
  extend Mobility

  translates :site_title, :site_description,
             :home_page_content, :contacts_page_content,
             :meta_keywords, :meta_description,
             backend: :jsonb

  belongs_to :agency

  validates :agency_id, uniqueness: true
end
