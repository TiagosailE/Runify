module Admin
  # Toda tela administrativa herda daqui. A autorizacao e um `before_action`
  # simples de proposito: existe UM papel (admin sim/nao) e um unico
  # administrador previsto, entao uma gem de politica seria peso morto.
  class BaseController < ApplicationController
    layout "admin"

    before_action :authenticate_user!
    before_action :require_admin

    private

    def require_admin
      return if current_user&.admin?

      redirect_to dashboard_path,
                  flash: { toast: { message: "Acesso restrito.", type: "error" } }
    end

    def record_audit(action, target_user, details = nil)
      AdminAuditLog.create!(
        admin: current_user,
        target_user: target_user,
        action: action,
        details: details
      )
    end
  end
end
