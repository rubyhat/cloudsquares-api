class Current < ActiveSupport::CurrentAttributes
  attribute :user, :agency

  # Возвращает true, если пользователь не авторизован
  def self.guest?
    user.nil?
  end

  # Возвращает true, если пользователь авторизован
  def self.authenticated?
    user.present?
  end
end
