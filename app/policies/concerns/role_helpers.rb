
module RoleHelpers
  def admin? = user&.role == "admin"
  def admin_manager? = user&.role == "admin_manager"
  def agent_admin? = user&.role == "agent_admin"
  def agent_manager? = user&.role == "agent_manager"
  def agent? = user&.role == "agent"
  def user? = user&.role == "user"
end
