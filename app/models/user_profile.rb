# app/models/user_profile.rb
# frozen_string_literal: true

class UserProfile < ApplicationRecord
  belongs_to :user

  validates :timezone, presence: true
  validates :locale,   presence: true

  # Хелперы для ФИО — пригодятся в сериализации/вьюхах
  def full_name
    [last_name, first_name, middle_name].compact_blank.join(" ")
  end

  def any_name_present?
    first_name.present? || last_name.present? || middle_name.present?
  end
end
