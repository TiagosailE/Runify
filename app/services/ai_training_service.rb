# Gera o plano de treino com a Gemini, dentro de limites calculados em Ruby.
# A IA e autora do plano mas nao autoridade sobre os numeros: o
# TrainingEnvelope define o que e seguro, o TrainingPlanValidator rejeita o
# que sair disso, e o FallbackPlanBuilder assume se a IA errar duas vezes.
class AiTrainingService
  MAX_ATTEMPTS = 2

  # training_plan/week_range presentes = regeneracao parcial (ex: mudanca de
  # dias de treino no meio do plano): gera so as semanas informadas e grava
  # nesse plano, em vez de criar um plano novo do zero.
  def initialize(user, training_plan: nil, week_range: nil)
    @user = user
    @envelope = TrainingEnvelope.new(user)
    @training_plan = training_plan
    @week_range = week_range || (1..@envelope.plan_weeks)
  end

  def generate_training_plan
    plan_data, source = plan_within_envelope
    persist(plan_data, source)
  rescue => e
    Rails.logger.error "Erro em generate_training_plan: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  # Tenta a IA ate MAX_ATTEMPTS vezes, dizendo no retry exatamente qual regra
  # foi quebrada. Cortar o numero em silencio nao serve: description e
  # instructions sao texto livre da IA, entao um plano com distancia cortada
  # e texto original passa a se contradizer -- e o usuario le o texto.
  def plan_within_envelope
    violations = []

    MAX_ATTEMPTS.times do |attempt|
      plan_data = request_plan(previous_violations: violations)
      validator = TrainingPlanValidator.new(plan_data, @envelope, week_range: @week_range)

      return [ plan_data, attempt.zero? ? "ai" : "ai_retry" ] if validator.valid?

      violations = validator.violations
      Rails.logger.warn "Plano da IA reprovado (tentativa #{attempt + 1}/#{MAX_ATTEMPTS}) " \
                        "para user #{@user.id}: #{violations.join(' | ')}"
    rescue GeminiClient::Error => e
      Rails.logger.warn "Falha na chamada da Gemini (tentativa #{attempt + 1}/#{MAX_ATTEMPTS}) " \
                        "para user #{@user.id}: #{e.message}"
    end

    Rails.logger.warn "Usando plano determinístico de fallback para user #{@user.id}"
    [ FallbackPlanBuilder.new(@user, @envelope, week_range: @week_range).build, "fallback" ]
  end

  def request_plan(previous_violations: [])
    GeminiClient.generate_json(
      build_prompt(previous_violations),
      response_schema: response_schema
    )
  end

  # Instrucoes longas em 27 treinos sao o que estoura o orcamento de tokens.
  # Pedir texto enxuto e o que mantem o plano inteiro cabendo na resposta.
  def brevity_rule
    "Seja direto: description em uma linha e instructions em no máximo 4 linhas curtas."
  end

  def build_prompt(previous_violations)
    sections = [
      "Você é um treinador de corrida. Monte um plano de treino para o atleta abaixo.",
      "## PERFIL DO ATLETA\n#{athlete_profile}",
      "## HISTÓRICO RECENTE\n#{activities_summary}",
      "## LIMITES OBRIGATÓRIOS (calculados a partir dos dados reais dele)\n#{@envelope.to_prompt_section}",
      "## REGRAS\n#{rules}"
    ]

    if regenerating_partial_plan?
      sections << "## CONTINUAÇÃO DE PLANO EXISTENTE\nEste plano já está em andamento " \
                  "(#{@envelope.plan_weeks} semanas no total). O atleta mudou os dias disponíveis " \
                  "para treino. Gere APENAS as semanas #{@week_range.min} a #{@week_range.max}, " \
                  "usando os novos dias disponíveis listados acima."
    end

    if previous_violations.any?
      sections << "## SUA RESPOSTA ANTERIOR FOI REJEITADA\n" \
                  "Corrija exatamente estes problemas:\n- #{previous_violations.join("\n- ")}"
    end

    sections.join("\n\n")
  end

  def athlete_profile
    [
      "- Nome: #{@user.username.presence || 'Atleta'}",
      "- Idade: #{@user.age || 'não informada'}",
      "- Peso: #{@user.weight || 'não informado'}kg",
      "- Altura: #{@user.height || 'não informada'}cm",
      "- Objetivo declarado: #{@user.goal.presence || 'melhorar condicionamento'}",
      "- Experiência declarada: #{@user.runner_level}",
      "- Anos de prática: #{@user.running_experience_years || 'não informado'}",
      "- Volume semanal atual: #{@user.weekly_mileage.present? ? "#{@user.weekly_mileage}km" : 'não informado'}",
      "- Melhor 5km: #{formatted_best(@user.best_5k_time)}",
      "- Melhor 10km: #{formatted_best(@user.best_10k_time)}",
      "- Melhor meia maratona: #{formatted_best(@user.best_half_marathon_time)}",
      "- Histórico de lesões: #{@user.injury_history.presence || 'nenhum relatado'}",
      "- Corrida mais longa nos últimos 30 dias: #{@envelope.longest_recent_run_km}km"
    ].join("\n")
  end

  def formatted_best(seconds)
    return "não informado" unless seconds.to_i.positive?

    minutes = seconds.to_i / 60
    rest = seconds.to_i % 60
    format("%d:%02d", minutes, rest)
  end

  def activities_summary
    recent = @user.activities.order(start_date: :desc).limit(10)
    return "Nenhuma atividade registrada." if recent.empty?

    recent.map do |activity|
      "- #{activity.formatted_date}: #{activity.distance_km}km em #{activity.duration_formatted} (pace #{activity.pace_per_km})"
    end.join("\n")
  end

  def rules
    common = [
      "1. NUNCA passe dos limites da seção anterior. Eles são rígidos e serão verificados.",
      "2. Use apenas os dias disponíveis listados.",
      "3. O objetivo declarado é o destino do plano, NÃO o primeiro treino.",
      "4. Progrida gradualmente: cada semana só um pouco acima da anterior.",
      "5. description e instructions precisam bater com os números do treino.",
      "6. #{brevity_rule}"
    ]

    if @envelope.run_walk?
      common << "7. Este atleta NUNCA CORREU. Todo treino tem format \"run_walk\", alternando " \
                "blocos de corrida leve com blocos de caminhada, e preenche o campo steps. " \
                "Não prescreva corrida contínua em nenhuma semana inicial e não use distância: " \
                "para ele o que importa é tempo, não quilometragem."
    else
      common << "7. Todo treino tem format \"continuous\" e distance_km preenchido."
    end

    common.join("\n")
  end

  # Os limites entram no proprio schema, entao a maior parte dos valores
  # impossiveis nem chega a ser gerada.
  def response_schema
    last_week_ceiling = @envelope.max_single_run_km_for_week(@week_range.max)

    {
      type: "OBJECT",
      properties: {
        analysis: { type: "STRING" },
        plan_duration_weeks: {
          type: "INTEGER",
          minimum: @envelope.plan_weeks,
          maximum: @envelope.plan_weeks
        },
        workouts: {
          type: "ARRAY",
          items: {
            type: "OBJECT",
            properties: {
              week: { type: "INTEGER", minimum: @week_range.min, maximum: @week_range.max },
              day: { type: "INTEGER", minimum: 1, maximum: 7 },
              type: { type: "STRING" },
              format: { type: "STRING", enum: Workout::FORMATS },
              distance_km: { type: "NUMBER", minimum: 0, maximum: last_week_ceiling, nullable: true },
              duration_minutes: { type: "INTEGER", minimum: 5, maximum: 300 },
              pace: { type: "STRING" },
              description: { type: "STRING" },
              instructions: { type: "STRING" },
              steps: {
                type: "ARRAY",
                nullable: true,
                items: {
                  type: "OBJECT",
                  properties: {
                    activity: { type: "STRING", enum: [ "run", "walk" ] },
                    seconds: { type: "INTEGER", minimum: 10, maximum: 7200 },
                    repeat: { type: "INTEGER", minimum: 1, maximum: 30 },
                    label: { type: "STRING" }
                  },
                  required: [ "activity", "seconds", "repeat" ]
                }
              }
            },
            required: [ "week", "day", "type", "format", "duration_minutes", "pace", "description", "instructions" ]
          }
        }
      },
      required: [ "analysis", "plan_duration_weeks", "workouts" ]
    }
  end

  def persist(plan_data, source)
    return persist_partial(plan_data, source) if regenerating_partial_plan?

    weeks = @envelope.plan_weeks
    start_date = Date.current.beginning_of_week(:monday)

    training_plan = @user.training_plans.create!(
      goal: @user.goal,
      status: "active",
      start_date: start_date,
      end_date: start_date + weeks.weeks - 1.day,
      total_weeks: weeks,
      plan_data: plan_data.merge("source" => source, "envelope" => envelope_snapshot)
    )

    plan_data["workouts"].each { |workout_data| create_workout(training_plan, workout_data) }

    training_plan
  end

  # Regrava so as semanas de @week_range no plano existente -- as semanas
  # anteriores (historico, inclusive treinos concluidos) ficam intactas.
  def persist_partial(plan_data, source)
    ActiveRecord::Base.transaction do
      @training_plan.workouts.where(week_number: @week_range, status: "pending").destroy_all
      plan_data["workouts"].each { |workout_data| create_workout(@training_plan, workout_data) }
    end

    @training_plan
  end

  def regenerating_partial_plan?
    @training_plan.present?
  end

  def create_workout(training_plan, workout_data)
    week = workout_data["week"].to_i
    day = workout_data["day"].to_i
    format_value = workout_data["format"].to_s
    format_value = "continuous" unless Workout::FORMATS.include?(format_value)

    distance = workout_data["distance_km"].to_f
    distance = nil unless distance.positive?

    # day e 1=Seg..7=Dom (mesma convencao do TrainingEnvelope). Ancorar na
    # segunda-feira da semana do plano -- em vez de em Date.current direto --
    # e o que faz "dia 2" cair numa terca de verdade, nao num offset contado
    # a partir do dia em que o plano foi gerado.
    monday = training_plan.start_date.beginning_of_week(:monday)
    scheduled_date = monday + (week - 1).weeks + (day - 1).days

    # Plano gerado no meio da semana: o que ja passou nao vira treino pendente.
    return if scheduled_date < Date.current

    training_plan.workouts.create!(
      week_number: week,
      day_of_week: day,
      scheduled_date: scheduled_date,
      workout_type: workout_data["type"].to_s,
      workout_format: format_value,
      distance: distance,
      duration: workout_data["duration_minutes"].to_i * 60,
      pace: workout_data["pace"].to_s,
      description: workout_data["description"].to_s,
      instructions: workout_data["instructions"].to_s,
      workout_details: workout_data,
      status: "pending"
    )
  end

  # Guardado junto do plano para dar rastro do porque daqueles numeros.
  def envelope_snapshot
    {
      "level" => @envelope.level.to_s,
      "run_walk" => @envelope.run_walk?,
      "max_single_run_km" => @envelope.max_single_run_km,
      "max_weekly_km" => @envelope.max_weekly_km,
      "fastest_pace_seconds" => @envelope.fastest_pace_seconds,
      "plan_weeks" => @envelope.plan_weeks,
      "sessions_per_week" => @envelope.sessions_per_week
    }
  end
end
