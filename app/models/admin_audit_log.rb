class AdminAuditLog < ApplicationRecord
  belongs_to :admin, class_name: "User"
  belongs_to :target_user, class_name: "User"

  # Toda acao de escrita do painel administrativo entra aqui. Nao ha registro
  # de LEITURA: o painel so mostra dado operacional (nunca peso, altura, data
  # de nascimento ou historico de lesao), entao abrir a ficha de alguem nao e
  # um ato que precise de prestacao de contas.
  ACTION_LABELS = {
    "strava_disconnect" => "Strava desconectado",
    "plan_cancel" => "Plano de treino cancelado",
    "password_reset_sent" => "E-mail de redefinicao de senha enviado"
  }.freeze

  ACTIONS = ACTION_LABELS.keys.freeze

  validates :action, inclusion: { in: ACTIONS, message: "não é uma ação conhecida" }

  scope :newest_first, -> { order(created_at: :desc) }

  def action_label
    ACTION_LABELS.fetch(action, action)
  end
end
