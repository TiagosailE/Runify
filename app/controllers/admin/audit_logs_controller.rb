module Admin
  class AuditLogsController < BaseController
    def index
      @audit_logs = AdminAuditLog.includes(:admin, :target_user).newest_first.limit(200)
    end
  end
end
