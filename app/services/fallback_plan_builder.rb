# Monta um plano de treino sem IA nenhuma, a partir do TrainingEnvelope.
#
# Devolve exatamente a MESMA estrutura que a Gemini deveria devolver, entao
# passa pelo mesmo validador e pela mesma persistencia -- um caminho so. E o
# que roda quando a IA falha duas vezes: melhor um plano conservador e
# coerente do que erro na tela ou plano contraditorio.
class FallbackPlanBuilder
  # Progressao caminhada/corrida no padrao consolidado (tipo Couch to 5K):
  # [segundos correndo, segundos caminhando, repeticoes]. O bloco de corrida
  # cresce e o de caminhada encolhe ate virar corrida continua na ultima
  # semana.
  RUN_WALK_PROGRESSION = [
    [ 60,   90, 8 ],
    [ 90,  120, 6 ],
    [ 120,  90, 6 ],
    [ 180,  90, 5 ],
    [ 300,  90, 4 ],
    [ 480, 120, 3 ],
    [ 720, 120, 2 ],
    [ 900, 120, 2 ],
    [ 1800,  0, 1 ]
  ].freeze

  WARMUP_SECONDS = 300
  COOLDOWN_SECONDS = 300

  def initialize(user, envelope = nil)
    @user = user
    @envelope = envelope || TrainingEnvelope.new(user)
  end

  def build
    {
      "analysis" => analysis_text,
      "plan_duration_weeks" => @envelope.plan_weeks,
      "workouts" => (1..@envelope.plan_weeks).flat_map { |week| workouts_for_week(week) }
    }
  end

  private

  def analysis_text
    if @envelope.run_walk?
      "Plano inicial de caminhada e corrida alternadas, montado de forma conservadora " \
      "por não haver histórico de corrida registrado. A cada semana o bloco de corrida " \
      "aumenta e o de caminhada diminui."
    else
      "Plano montado a partir do seu histórico recente, respeitando aumento máximo de " \
      "10% por semana para reduzir risco de lesão."
    end
  end

  def workouts_for_week(week)
    days = @envelope.training_days.first(@envelope.sessions_per_week)

    if @envelope.run_walk?
      days.map { |day| run_walk_workout(week, day) }
    else
      continuous_week(week, days)
    end
  end

  def run_walk_workout(week, day)
    run_seconds, walk_seconds, repeats = RUN_WALK_PROGRESSION[
      (week - 1).clamp(0, RUN_WALK_PROGRESSION.size - 1)
    ]

    total = WARMUP_SECONDS + (repeats * (run_seconds + walk_seconds)) + COOLDOWN_SECONDS

    {
      "week" => week,
      "day" => day,
      "type" => "Caminhada/Corrida",
      "format" => "run_walk",
      "distance_km" => nil,
      "duration_minutes" => (total / 60.0).round,
      "pace" => "confortável",
      "description" => "#{repeats}x (#{humanize(run_seconds)} correndo / #{humanize(walk_seconds)} caminhando)",
      "instructions" => run_walk_instructions(run_seconds, walk_seconds, repeats),
      "steps" => run_walk_steps(run_seconds, walk_seconds, repeats)
    }
  end

  def run_walk_instructions(run_seconds, walk_seconds, repeats)
    lines = [ "Aquecimento: 5 minutos de caminhada leve" ]
    lines << if walk_seconds.zero?
      "Principal: #{humanize(run_seconds)} de corrida contínua em ritmo confortável"
    else
      "Principal: #{repeats}x alternando #{humanize(run_seconds)} de corrida leve " \
      "com #{humanize(walk_seconds)} de caminhada"
    end
    lines << "Desaquecimento: 5 minutos de caminhada leve"
    lines << "Corra devagar o suficiente para conseguir conversar. Velocidade não importa agora."
    lines.join("\n")
  end

  def run_walk_steps(run_seconds, walk_seconds, repeats)
    steps = [ { "activity" => "walk", "seconds" => WARMUP_SECONDS, "repeat" => 1, "label" => "Aquecimento" } ]
    steps << { "activity" => "run", "seconds" => run_seconds, "repeat" => repeats, "label" => "Corrida" }
    if walk_seconds.positive?
      steps << { "activity" => "walk", "seconds" => walk_seconds, "repeat" => repeats, "label" => "Caminhada" }
    end
    steps << { "activity" => "walk", "seconds" => COOLDOWN_SECONDS, "repeat" => 1, "label" => "Desaquecimento" }
    steps
  end

  # Distribui o orcamento semanal: o longao leva 40% (respeitando tambem o
  # teto de treino unico) e o resto se divide entre as corridas leves. Feito
  # assim o total da semana nunca estoura o limite, seja qual for o numero
  # de sessoes.
  def continuous_week(week, days)
    weekly_budget = @envelope.max_weekly_km_for_week(week)
    long_km = [
      (weekly_budget * TrainingEnvelope::LONG_RUN_SHARE_OF_WEEK).round(1),
      @envelope.max_single_run_km_for_week(week)
    ].min

    # floor() garante que a soma das corridas leves nunca ultrapasse o teto
    # semanal por arredondamento.
    easy_count = [ days.size - 1, 1 ].max
    easy_km = ((weekly_budget - long_km) / easy_count).floor(1)

    if easy_km < 0.5
      # Orcamento apertado demais: encolhe o longao em vez de estourar a semana.
      easy_km = 0.5
      long_km = [ (weekly_budget - (easy_km * easy_count)).floor(1), 0.5 ].max
    end

    days.each_with_index.map do |day, index|
      long_run = (index == days.size - 1) && days.size > 1
      distance = long_run ? long_km : easy_km
      distance = [ distance, @envelope.max_single_run_km_for_week(week) ].min

      continuous_workout(week, day, distance, long_run)
    end
  end

  def continuous_workout(week, day, distance, long_run)
    pace_seconds = @envelope.suggested_easy_pace_seconds
    pace_seconds += 20 if long_run
    pace_seconds = pace_seconds.clamp(@envelope.fastest_pace_seconds, @envelope.slowest_pace_seconds)

    {
      "week" => week,
      "day" => day,
      "type" => long_run ? "Longão" : "Corrida Leve",
      "format" => "continuous",
      "distance_km" => distance,
      "duration_minutes" => ((distance * pace_seconds) / 60.0).round,
      "pace" => @envelope.format_pace(pace_seconds),
      "description" => long_run ? "Corrida longa em ritmo confortável" : "Corrida leve em ritmo confortável",
      "instructions" => [
        "Aquecimento: 5 minutos de caminhada ou trote muito leve",
        "Principal: #{distance}km em torno de #{@envelope.format_pace(pace_seconds)}/km",
        "Desaquecimento: 5 minutos de caminhada",
        "Se não conseguir manter conversa, diminua o ritmo."
      ].join("\n"),
      "steps" => []
    }
  end

  def humanize(seconds)
    return "#{seconds}s" if seconds < 60
    minutes = seconds / 60
    rest = seconds % 60
    rest.zero? ? "#{minutes}min" : "#{minutes}min#{rest}s"
  end
end
