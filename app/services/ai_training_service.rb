# Gera o plano de treino com a Gemini, dentro de limites calculados em Ruby.
#
# A IA continua sendo a autora do plano, mas nao e a autoridade sobre os
# numeros: o TrainingEnvelope calcula o que e seguro para aquele atleta, o
# prompt recebe esses limites, o responseSchema ja impede boa parte dos
# valores absurdos na geracao, e o TrainingPlanValidator rejeita o que passar.
# Se a IA errar duas vezes, entra o plano deterministico do
# FallbackPlanBuilder -- nunca um plano incoerente e nunca um erro na tela.
class AiTrainingService
  MAX_ATTEMPTS = 2

  def initialize(user)
    @user = user
    @envelope = TrainingEnvelope.new(user)
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
      validator = TrainingPlanValidator.new(plan_data, @envelope)

      return [ plan_data, attempt.zero? ? "ai" : "ai_retry" ] if validator.valid?

      violations = validator.violations
      Rails.logger.warn "Plano da IA reprovado (tentativa #{attempt + 1}/#{MAX_ATTEMPTS}) " \
                        "para user #{@user.id}: #{violations.join(' | ')}"
    rescue GeminiClient::Error => e
      Rails.logger.warn "Falha na chamada da Gemini (tentativa #{attempt + 1}/#{MAX_ATTEMPTS}) " \
                        "para user #{@user.id}: #{e.message}"
    end

    Rails.logger.warn "Usando plano determinístico de fallback para user #{@user.id}"
    [ FallbackPlanBuilder.new(@user, @envelope).build, "fallback" ]
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

    if previous_violations.any?
      sections << "## SUA RESPOSTA ANTERIOR FOI REJEITADA\n" \
                  "Corrija exatamente estes problemas:\n- #{previous_violations.join("\n- ")}"
    end

    sections.join("\n\n")
  end

  def athlete_profile
    # Estes campos existem no banco desde o onboarding, mas nao eram enviados
    # -- a IA prescrevia no escuro. Era a causa real de plano absurdo, mais do
    # que a redacao do prompt.
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
    last_week_ceiling = @envelope.max_single_run_km_for_week(@envelope.plan_weeks)

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
              week: { type: "INTEGER", minimum: 1, maximum: @envelope.plan_weeks },
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
    weeks = @envelope.plan_weeks

    training_plan = @user.training_plans.create!(
      goal: @user.goal,
      status: "active",
      start_date: Date.today,
      end_date: Date.today + weeks.weeks,
      total_weeks: weeks,
      plan_data: plan_data.merge("source" => source, "envelope" => envelope_snapshot)
    )

    plan_data["workouts"].each { |workout_data| create_workout(training_plan, workout_data) }

    training_plan
  end

  def create_workout(training_plan, workout_data)
    week = workout_data["week"].to_i
    day = workout_data["day"].to_i
    format_value = workout_data["format"].to_s
    format_value = "continuous" unless Workout::FORMATS.include?(format_value)

    distance = workout_data["distance_km"].to_f
    distance = nil unless distance.positive?

    training_plan.workouts.create!(
      week_number: week,
      day_of_week: day,
      scheduled_date: Date.today + (week - 1).weeks + (day - 1).days,
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

  # Guardado junto do plano para dar rastro do porque daqueles numeros --
  # serve para depurar e para a coleta de dados do TG.
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
