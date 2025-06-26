# frozen_string_literal: true

# == Schema Information
#
# Table name: property_photos
#
#  id               :uuid             not null, primary key
#  property_id      :uuid             not null, foreign key
#  file_url         :string           not null              # основной файл
#  file_preview_url :string                                 # уменьшенная копия
#  file_retina_url  :string                                 # retina-версия
#  is_main          :boolean          default(FALSE), not null
#  position         :integer          default(1), not null
#  access           :string           default("public"), not null
#  uploaded_by_id   :uuid             not null
#  agency_id        :uuid             not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_property_photos_on_property_id_main  (property_id, is_main) UNIQUE WHERE is_main = true

class PropertyPhoto < ApplicationRecord
  # Ассоциации
  belongs_to :property
  belongs_to :uploaded_by, class_name: "User"
  belongs_to :agency

  # Валидации
  validates :file_url, :access, :uploaded_by_id, :agency_id, presence: true
  validates :access, inclusion: { in: %w[public private] }
  validates :position, numericality: { greater_than_or_equal_to: 1 }

  # В одной недвижимости может быть только одно основное фото
  validates :is_main, uniqueness: { scope: :property_id }, if: -> { is_main? }

  # Сортировка по позиции
  default_scope { order(:position) }

  # Удобный скоуп для публичных фото
  scope :public_access, -> { where(access: "public") }
end
# frozen_string_literal: true

# == Schema Information
#
# Table name: property_photos
#
#  id               :uuid             not null, primary key
#  property_id      :uuid             not null, foreign key
#  file_url         :string           not null              # основной файл
#  file_preview_url :string                                 # уменьшенная копия
#  file_retina_url  :string                                 # retina-версия
#  is_main          :boolean          default(FALSE), not null
#  position         :integer          default(1), not null
#  access           :string           default("public"), not null
#  uploaded_by_id   :uuid             not null
#  agency_id        :uuid             not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_property_photos_on_property_id_main  (property_id, is_main) UNIQUE WHERE is_main = true

class PropertyPhoto < ApplicationRecord
  # Ассоциации
  belongs_to :property
  belongs_to :uploaded_by, class_name: "User"
  belongs_to :agency

  # Валидации
  validates :file_url, :access, :uploaded_by_id, :agency_id, presence: true
  validates :access, inclusion: { in: %w[public private] }
  validates :position, numericality: { greater_than_or_equal_to: 1 }

  # В одной недвижимости может быть только одно основное фото
  validates :is_main, uniqueness: { scope: :property_id }, if: -> { is_main? }

  # Сортировка по позиции
  default_scope { order(:position) }

  # Удобный скоуп для публичных фото
  scope :public_access, -> { where(access: "public") }
end
