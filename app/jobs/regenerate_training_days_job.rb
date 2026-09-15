# Roda a chamada da IA fora do request de Settings -- trocar os dias de
# treino precisa ser rapido para quem esta na tela, a regeneracao do plano
# nao.
class RegenerateTrainingDaysJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    plan = user.active_training_plan
    return unless plan

    current_week = [ plan.current_week, 1 ].max
    return if current_week > plan.total_weeks

    week_range = current_week..plan.total_weeks
    AiTrainingService.new(user, training_plan: plan, week_range: week_range).generate_training_plan
  rescue => e
    Rails.logger.error "Erro ao regenerar plano apos troca de dias de treino (user #{user_id}): #{e.message}"
  end
end
