# frozen_string_literal: true

class PropertyComment < ApplicationRecord
  belongs_to :property
  belongs_to :user

  # Комментарий может быть удалён, но не физически
  scope :active, -> { where(is_deleted: false) }

  validates :body, presence: true

  # Санитизация Rich Text комментария от XSS
  before_save :sanitize_body
  before_update :track_edit

  # TODO: проверить все модели, где-то is_active где-то is_deleted меняется
  def soft_delete!
    update(is_deleted: true, deleted_at: Time.zone.now)
  end

  private

  # Удаление потенциально вредного HTML из body
  def sanitize_body
    self.body = Loofah.fragment(body).scrub!(:prune).to_s
  end

  # Увеличение счётчика и метки редактирования, если тело изменилось
  def track_edit
    if body_changed?
      self.edited = true
      self.edited_at = Time.zone.now
      self.edit_count += 1
    end
  end
end
