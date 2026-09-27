# Ajusta a carga das semanas seguintes com base no feedback do atleta.
#
# Mesma divisao de responsabilidade da geracao: a IA sugere a direcao e a
# intensidade do ajuste, mas o resultado passa pelo teto do TrainingEnvelope
# antes de virar treino -- senao aumentos sucessivos compõem sem limite.
# Roda no maximo uma vez por semana por plano (last_adjusted_week): cada
# chamada multiplica todos os treinos pendentes, entao repetir na mesma semana
# acumularia o aumento.
class AiAdjustmentService
  # Aumentar e mais arriscado que reduzir, entao o limite e assimetrico.
  MAX_INCREASE_PERCENT = 10
  MAX_DECREASE_PERCENT = 20
  # Chaves batem com data-difficulty em training/index.html.erb -- o valor
  # que chega aqui e sempre uma dessas tres, ou nil quando o atleta pulou o
  # feedback.
  DIFFICULTY_LABELS = { "facil" => "fácil", "medio" => "médio", "dificil" => "difícil" }.freeze

  def initialize(user, training_plan)
    @user = user
    @training_plan = training_plan
    @envelope = TrainingEnvelope.new(user)
  end

  def analyze_and_adjust
    current_week = @training_plan.current_week
    return unless current_week > 1
    return if @training_plan.last_adjusted_week == current_week

    previous_week_workouts = @training_plan.workouts_for_week(current_week - 1)
    completed_workouts = previous_week_workouts.select(&:completed?)

    return if completed_workouts.empty?

    adjustment_data = GeminiClient.generate_json(
      build_adjustment_prompt(completed_workouts, current_week),
      response_schema: response_schema,
      max_output_tokens: 4096
    )
    apply_adjustments(adjustment_data, current_week)
  rescue => e
    Rails.logger.error "Erro em AiAdjustmentService: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def build_adjustment_prompt(completed_workouts, current_week)
    feedback_summary = completed_workouts.map do |workout|
      feedback = workout.workout_details&.dig("user_feedback")
      difficulty = DIFFICULTY_LABELS[feedback&.dig("difficulty")] || "não informado"
      notes = feedback&.dig("notes") || ""

      <<~WORKOUT
        - Treino: #{workout.workout_type}
          Distância planejada: #{workout.distance_km}km
          Pace planejado: #{workout.pace}
          Dificuldade reportada: #{difficulty}
          Observações do atleta: #{notes.present? ? notes : 'Nenhuma'}
      WORKOUT
    end.join("\n")

    completion_rate = (completed_workouts.count.to_f / @training_plan.workouts_for_week(current_week - 1).count * 100).round

    recent_activities = @user.activities.where("start_date >= ?", 7.days.ago).order(start_date: :desc)
    activities_summary = if recent_activities.any?
      recent_activities.map do |act|
        "- #{act.start_date.strftime('%d/%m')}: #{(act.distance/1000.0).round(2)}km, pace #{format_pace(act.average_speed)}"
      end.join("\n")
    else
      "Nenhuma atividade registrada na última semana"
    end

    <<~PROMPT
      Você é um treinador de corrida experiente analisando o progresso do atleta para ajustar o plano de treino.

      ### CONTEXTO DO PLANO
      - Objetivo: #{@user.goal}
      - Semana atual: #{current_week} de #{@training_plan.total_weeks}
      - Nível do atleta: #{@user.running_experience&.capitalize || 'Não informado'}
      - Taxa de conclusão semana passada: #{completion_rate}%

      ### FEEDBACKS DA SEMANA PASSADA (Semana #{current_week - 1})
      #{feedback_summary}

      ### ATIVIDADES RECENTES (Última Semana, qualquer origem — manual, importada ou Strava)
      #{activities_summary}

      ### ANÁLISE NECESSÁRIA

      Analise os seguintes fatores:
      1. **Dificuldade reportada**: Se a maioria dos treinos foi "fácil", "médio" ou "difícil"
      2. **Taxa de conclusão**: Se o atleta pulou treinos (pode indicar sobrecarga ou falta de motivação)
      3. **Observações qualitativas**: O que o atleta escreveu nos feedbacks
      4. **Atividades recentes**: Compare pace planejado vs executado, quando houver dado

      ### REGRAS DE AJUSTE

      - Se a maioria dos treinos foi "fácil" e conclusão >= 80%: Aumentar carga em 5-10%
      - Se algum treino foi "difícil" ou conclusão < 60%: Reduzir carga em 10-15%
      - Se a maioria foi "médio" e conclusão >= 60%: Manter progressão normal (5%)
      - Se há observações de dor/lesão: Reduzir carga e sugerir descanso
      - Considerar progressão gradual (regra dos 10% máximo)

      ### IMPORTANTE

      - `adjustment_percentage` é sempre positivo: quem define a direção é `adjustment_type`.
      - "maintain" significa manter a carga como está, sem aumento nenhum.
      - `red_flags` deve conter alertas como "possível overtraining" ou "risco de lesão" quando aplicável.
      - Seja conservador: priorize saúde sobre performance.
    PROMPT
  end

  def response_schema
    {
      type: "OBJECT",
      properties: {
        analysis: { type: "STRING" },
        adjustment_type: { type: "STRING", enum: [ "increase", "decrease", "maintain" ] },
        adjustment_percentage: { type: "INTEGER", minimum: 0, maximum: MAX_DECREASE_PERCENT },
        reasoning: { type: "STRING" },
        recommendations: { type: "ARRAY", items: { type: "STRING" } },
        red_flags: { type: "ARRAY", items: { type: "STRING" } }
      },
      required: [ "analysis", "adjustment_type", "adjustment_percentage", "reasoning" ]
    }
  end

  def apply_adjustments(adjustment_data, current_week)
    adjustment_type = adjustment_data["adjustment_type"]
    percentage = clamped_percentage(adjustment_type, adjustment_data["adjustment_percentage"])
    factor = adjustment_factor(adjustment_type, percentage)

    remaining_workouts = @training_plan.workouts.where("week_number >= ? AND status = ?", current_week, "pending")

    adjusted_count = 0

    # Numa transacao com a marca da semana: falha no meio nao deixa parte dos
    # treinos ajustada sem marca, o que faria a proxima execucao compor de novo.
    ActiveRecord::Base.transaction do
      remaining_workouts.each do |workout|
        original_distance = workout.distance
        original_duration = workout.duration

        if workout.distance.present?
          # Teto do envelope para a semana daquele treino: sem isso, aumentos
          # sucessivos de 10% compõem sem limite semana após semana.
          ceiling = @envelope.max_single_run_km_for_week(workout.week_number)
          workout.distance = (workout.distance * factor).round(2).clamp(1.0, ceiling)
        end

        workout.duration = adjusted_duration(workout, factor) if workout.duration.present?

        workout.workout_details = (workout.workout_details || {}).merge({
          "ai_adjustment" => {
            "adjusted_at" => Time.current.iso8601,
            "type" => adjustment_type,
            "percentage" => (percentage * 100).round(1),
            "reason" => adjustment_data["analysis"],
            "recommendations" => adjustment_data["recommendations"],
            "red_flags" => adjustment_data["red_flags"],
            "original_distance" => original_distance,
            "original_duration" => original_duration
          }
        })

        if workout.save
          adjusted_count += 1
        end
      end

      @training_plan.update!(last_adjusted_week: current_week)
    end

    Rails.logger.info "=== AI ADJUSTMENT APPLIED ==="
    Rails.logger.info "Type: #{adjustment_type}"
    Rails.logger.info "Percentage: #{(percentage * 100).round(1)}%"
    Rails.logger.info "Workouts adjusted: #{adjusted_count}"
    Rails.logger.info "Analysis: #{adjustment_data['analysis']}"
    Rails.logger.info "Red Flags: #{adjustment_data['red_flags'].join(', ')}" if adjustment_data["red_flags"]&.any?

    if adjustment_data["red_flags"]&.any?
      NotificationService.send_adjustment_alert(@user, adjustment_data)
    end

    true
  end

  # A IA so decide a direcao e a intensidade; o limite por direcao e nosso.
  # "maintain" (ou qualquer tipo desconhecido) nao move nada.
  def clamped_percentage(adjustment_type, requested)
    limit = case adjustment_type
    when "increase" then MAX_INCREASE_PERCENT
    when "decrease" then MAX_DECREASE_PERCENT
    else 0
    end

    requested.to_f.abs.clamp(0, limit) / 100.0
  end

  # O teto de duracao so impede o aumento de passar dele: um treino que ja
  # estava acima (o validador nao amarra duracao ao teto da semana) nunca e
  # reduzido por causa de um aumento.
  def adjusted_duration(workout, factor)
    ceiling = [ @envelope.max_duration_seconds_for_week(workout.week_number), workout.duration ].max

    [ [ (workout.duration * factor).to_i, 600 ].max, ceiling ].min
  end

  def adjustment_factor(adjustment_type, percentage)
    case adjustment_type
    when "increase" then 1 + percentage
    when "decrease" then 1 - percentage
    else 1.0
    end
  end

  def format_pace(speed_m_s)
    return "N/A" unless speed_m_s && speed_m_s > 0
    pace_min_km = 1000.0 / (speed_m_s * 60)
    mins = pace_min_km.floor
    secs = ((pace_min_km - mins) * 60).round
    "#{mins}:#{secs.to_s.rjust(2, '0')}/km"
  end
end
