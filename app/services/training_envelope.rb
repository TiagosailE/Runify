# Calcula, sem IA, os limites seguros de treino de um atleta.
#
# Existe porque prompt nao da garantia: LLM e probabilistico, entao os
# numeros que chegam no usuario precisam passar por uma trava deterministica.
# Esta classe e a fonte unica desses limites -- o prompt recebe eles, o
# validador rejeita o que sair deles, e o plano de fallback e montado a
# partir deles.
class TrainingEnvelope
  # Pace mais rapido que qualquer humano sustenta num treino (o recorde
  # mundial dos 5km e ~2:24/km) e o ponto em que "correr" ja virou caminhada.
  FASTEST_HUMAN_PACE = 150
  SLOWEST_HUMAN_PACE = 720

  # Nunca prescrever mais rapido que 10% acima do melhor tempo que o atleta
  # ja provou -- treino nao se corre em ritmo de recorde pessoal.
  BEST_EFFORT_MARGIN = 0.90

  # Preditor de lesao com melhor evidencia disponivel (coorte de 5.200
  # corredores, British Journal of Sports Medicine): o risco vem do pico de
  # UMA corrida acima de ~110% da mais longa dos ultimos 30 dias, nao do
  # total semanal. A regra dos 10% semanais nunca foi validada.
  SINGLE_RUN_SPIKE_LIMIT = 1.10
  RECENT_HISTORY_WINDOW = 30.days

  # Longao raramente passa de 40% do volume semanal.
  LONG_RUN_SHARE_OF_WEEK = 0.4

  # Quem nunca correu faz caminhada/corrida: a sessao inteira (incluindo
  # caminhada) fica nesta faixa, e distancia e consequencia, nao prescricao.
  ABSOLUTE_BEGINNER_SESSION_CEILING_KM = 3.0
  ABSOLUTE_BEGINNER_WEEKLY_CEILING_KM = 9.0

  # Sair do zero ate 5km com seguranca leva ~9 semanas (protocolo consolidado
  # tipo Couch to 5K). Comprimir isso em 4 semanas e o que empurra qualquer
  # treinador -- humano ou IA -- a inventar salto impossivel.
  PLAN_WEEKS_BY_LEVEL = {
    absolute_beginner: 9,
    beginner: 8,
    intermediate: 6,
    advanced: 6
  }.freeze
  MIN_PLAN_WEEKS = 4
  MAX_PLAN_WEEKS = 12

  SESSIONS_BY_LEVEL = {
    absolute_beginner: 3,
    beginner: 3,
    intermediate: 4,
    advanced: 5
  }.freeze

  # Fronteiras de volume semanal declarado (km) entre niveis.
  BEGINNER_WEEKLY_KM = 15
  INTERMEDIATE_WEEKLY_KM = 40

  # Corrida leve se corre ~75s/km mais lento que o melhor esforco comprovado.
  # Sem nenhum tempo comprovado, um padrao conservador por nivel.
  EASY_PACE_OFFSET = 75
  DEFAULT_EASY_PACE = {
    absolute_beginner: 540,
    beginner: 480,
    intermediate: 390,
    advanced: 330
  }.freeze

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def level
    @level ||= begin
      declared = user.running_experience
      weekly = declared_weekly_km

      if no_history? && weekly.zero? && declared != "advanced" && declared != "intermediate"
        :absolute_beginner
      elsif declared == "advanced" || weekly > INTERMEDIATE_WEEKLY_KM
        :advanced
      elsif declared == "intermediate" || weekly >= BEGINNER_WEEKLY_KM
        :intermediate
      else
        :beginner
      end
    end
  end

  def run_walk?
    level == :absolute_beginner
  end

  # Teto absoluto de distancia para UM treino. Nenhum treino do plano pode
  # passar disto, venha da IA ou do fallback.
  def max_single_run_km
    @max_single_run_km ||=
      if run_walk?
        ABSOLUTE_BEGINNER_SESSION_CEILING_KM
      elsif longest_recent_run_km.positive?
        (longest_recent_run_km * SINGLE_RUN_SPIKE_LIMIT).round(1)
      elsif declared_weekly_km.positive?
        (declared_weekly_km * LONG_RUN_SHARE_OF_WEEK).round(1)
      else
        # Declarou nivel mas nao deixou nenhum numero: comeca conservador.
        level == :beginner ? 3.0 : 5.0
      end
  end

  def max_weekly_km
    @max_weekly_km ||=
      if run_walk?
        ABSOLUTE_BEGINNER_WEEKLY_CEILING_KM
      elsif declared_weekly_km.positive?
        (declared_weekly_km * SINGLE_RUN_SPIKE_LIMIT).round(1)
      else
        (max_single_run_km / LONG_RUN_SHARE_OF_WEEK).round(1)
      end
  end

  # Os tetos acima valem para a semana 1. Eles sobem a cada semana porque, ao
  # chegar la, o atleta ja treinou as anteriores -- travar a semana 8 no
  # limite da semana 1 tornaria qualquer progressao impossivel. O crescimento
  # e o mesmo 110% por degrau, que e o limite com evidencia.
  def max_single_run_km_for_week(week)
    grow(max_single_run_km, week)
  end

  def max_weekly_km_for_week(week)
    grow(max_weekly_km, week)
  end

  def fastest_pace_seconds
    @fastest_pace_seconds ||= begin
      from_best = proven_best_pace_seconds
      floor = from_best ? (from_best * BEST_EFFORT_MARGIN).round : FASTEST_HUMAN_PACE
      [ floor, FASTEST_HUMAN_PACE ].max
    end
  end

  def slowest_pace_seconds
    SLOWEST_HUMAN_PACE
  end

  # fastest_pace_seconds e teto de PERMISSAO, nao prescricao: para quem nao
  # tem tempo comprovado ele cai no limite humano (2:30/km), que seria
  # absurdo prescrever. Este e o ritmo que de fato se recomenda para corrida
  # leve.
  def suggested_easy_pace_seconds
    @suggested_easy_pace_seconds ||= begin
      best = proven_best_pace_seconds
      pace = best ? best + EASY_PACE_OFFSET : DEFAULT_EASY_PACE.fetch(level)
      pace.clamp(fastest_pace_seconds, slowest_pace_seconds)
    end
  end

  def plan_weeks
    PLAN_WEEKS_BY_LEVEL.fetch(level).clamp(MIN_PLAN_WEEKS, MAX_PLAN_WEEKS)
  end

  def sessions_per_week
    [ SESSIONS_BY_LEVEL.fetch(level), training_days.size ].min
  end

  # Dias da semana (1=Seg .. 7=Dom) em que o atleta pode treinar.
  def training_days
    @training_days ||= begin
      declared = Array(user.preferred_training_days).map(&:to_i).select { |d| d.between?(1, 7) }
      declared = Array(user.available_days).map(&:to_i).select { |d| d.between?(1, 7) } if declared.empty?
      declared.uniq.sort.presence || [ 1, 3, 5 ]
    end
  end

  def longest_recent_run_km
    @longest_recent_run_km ||= begin
      furthest = user.activities
                     .where("start_date >= ?", RECENT_HISTORY_WINDOW.ago)
                     .maximum(:distance)
      furthest ? (furthest / 1000.0).round(2) : 0.0
    end
  end

  def injury_history
    user.injury_history.presence
  end

  # Resumo em texto que vai dentro do prompt. Manter curto: o modelo respeita
  # melhor um bloco de regras enxuto do que um texto longo.
  def to_prompt_section
    lines = [
      "- Nivel calculado: #{level_label}",
      "- Formato obrigatorio: #{run_walk? ? 'caminhada/corrida alternadas (NAO corrida continua)' : 'corrida continua'}",
      "- Distancia maxima de UM treino na semana 1: #{max_single_run_km}km (limite rigido)",
      "- Esse teto sobe 10% por semana: semana #{plan_weeks} pode chegar a #{max_single_run_km_for_week(plan_weeks)}km",
      "- Volume maximo da semana 1: #{max_weekly_km}km (mesmo crescimento de 10% por semana)",
      "- Pace permitido: entre #{format_pace(fastest_pace_seconds)} e #{format_pace(slowest_pace_seconds)} por km",
      "- Pace sugerido para corrida leve: ~#{format_pace(suggested_easy_pace_seconds)}/km",
      "- Duracao do plano: #{plan_weeks} semanas",
      "- Treinos por semana: #{sessions_per_week}",
      "- Dias disponiveis (1=Seg..7=Dom): #{training_days.join(', ')}"
    ]
    lines << "- Historico de lesao relatado: #{injury_history}" if injury_history
    lines.join("\n")
  end

  def level_label
    {
      absolute_beginner: "Iniciante absoluto (nunca correu)",
      beginner: "Iniciante",
      intermediate: "Intermediario",
      advanced: "Avancado"
    }.fetch(level)
  end

  def format_pace(seconds)
    format("%d:%02d", seconds / 60, seconds % 60)
  end

  private

  def grow(base, week)
    steps = week.to_i.clamp(1, MAX_PLAN_WEEKS) - 1
    (base * (SINGLE_RUN_SPIKE_LIMIT**steps)).round(1)
  end

  def no_history?
    longest_recent_run_km.zero?
  end

  def declared_weekly_km
    @declared_weekly_km ||= user.weekly_mileage.to_f.clamp(0, User::MAX_WEEKLY_MILEAGE_KM)
  end

  # Melhor pace ja comprovado pelo atleta, em segundos por km. Usa a prova
  # mais longa disponivel: quanto mais longa, mais representativa do ritmo
  # que ele sustenta em treino.
  def proven_best_pace_seconds
    candidates = [
      (user.best_half_marathon_time.to_f / 21.0975 if user.best_half_marathon_time.to_i.positive?),
      (user.best_10k_time.to_f / 10.0 if user.best_10k_time.to_i.positive?),
      (user.best_5k_time.to_f / 5.0 if user.best_5k_time.to_i.positive?)
    ].compact

    return nil if candidates.empty?

    candidates.min.round
  end
end
