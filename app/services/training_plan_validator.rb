# Confere um plano (venha da IA ou do fallback) contra o TrainingEnvelope.
#
# E a trava deterministica: nenhum plano chega no usuario sem passar por
# aqui. Devolve a lista de violacoes em texto -- vazia significa aprovado.
# As mensagens sao reaproveitadas no retry, dizendo para a IA exatamente qual
# regra ela quebrou.
class TrainingPlanValidator
  PACE_PATTERN = /(\d{1,2}):(\d{2})/

  def initialize(plan_data, envelope, week_range: nil)
    @plan_data = plan_data
    @envelope = envelope
    @week_range = week_range || (1..envelope.plan_weeks)
  end

  def valid?
    violations.empty?
  end

  def violations
    @violations ||= begin
      list = structural_violations
      list.empty? ? workout_violations + weekly_volume_violations : list
    end
  end

  private

  def workouts
    Array(@plan_data["workouts"])
  end

  def structural_violations
    return [ "resposta não é um objeto JSON válido" ] unless @plan_data.is_a?(Hash)
    return [ "campo 'workouts' ausente ou não é uma lista" ] unless @plan_data["workouts"].is_a?(Array)
    return [ "nenhum treino foi gerado" ] if workouts.empty?

    []
  end

  def workout_violations
    workouts.each_with_index.flat_map do |workout, index|
      label = "treino ##{index + 1}"
      week = workout["week"].to_i
      day = workout["day"].to_i

      errors = []
      errors << "#{label}: semana #{week} fora do intervalo esperado (#{@week_range.min} a #{@week_range.max})" unless @week_range.cover?(week)
      errors << "#{label}: dia #{day} inválido (precisa ser 1 a 7)" unless day.between?(1, 7)
      errors << "#{label}: dia #{day} não está entre os dias disponíveis do atleta (#{@envelope.training_days.join(', ')})" if day.between?(1, 7) && !@envelope.training_days.include?(day)
      errors.concat(format_violations(workout, label))
      errors.concat(distance_violations(workout, label, week))
      errors.concat(pace_violations(workout, label))
      errors.concat(duration_violations(workout, label))
      errors
    end
  end

  def format_violations(workout, label)
    format_value = workout["format"].to_s

    unless Workout::FORMATS.include?(format_value)
      return [ "#{label}: formato '#{format_value}' inválido (use continuous ou run_walk)" ]
    end

    if @envelope.run_walk? && format_value != "run_walk"
      return [ "#{label}: atleta nunca correu, todo treino precisa ser run_walk (veio '#{format_value}')" ]
    end

    []
  end

  def distance_violations(workout, label, week)
    distance = workout["distance_km"]
    run_walk = workout["format"].to_s == "run_walk"

    if distance.nil? || distance.to_f.zero?
      return run_walk ? [] : [ "#{label}: distância ausente em treino de corrida contínua" ]
    end

    ceiling = @envelope.max_single_run_km_for_week(week)
    return [] if distance.to_f <= ceiling

    [ "#{label}: #{distance}km passa do limite de #{ceiling}km para a semana #{week}" ]
  end

  def pace_violations(workout, label)
    paces = workout["pace"].to_s.scan(PACE_PATTERN).map { |min, sec| (min.to_i * 60) + sec.to_i }
    return [] if paces.empty?

    paces.filter_map do |pace|
      if pace < @envelope.fastest_pace_seconds
        "#{label}: pace #{@envelope.format_pace(pace)}/km é mais rápido que o limite de #{@envelope.format_pace(@envelope.fastest_pace_seconds)}/km"
      elsif pace > @envelope.slowest_pace_seconds
        "#{label}: pace #{@envelope.format_pace(pace)}/km é mais lento que caminhada"
      end
    end
  end

  def duration_violations(workout, label)
    minutes = workout["duration_minutes"].to_i
    return [ "#{label}: duração ausente ou zerada" ] unless minutes.positive?
    return [ "#{label}: duração de #{minutes} minutos é implausível" ] if minutes > 300

    []
  end

  def weekly_volume_violations
    workouts.group_by { |workout| workout["week"].to_i }.filter_map do |week, week_workouts|
      total = week_workouts.sum { |workout| workout["distance_km"].to_f }
      next if total.zero?

      ceiling = @envelope.max_weekly_km_for_week(week)
      next if total <= ceiling

      "semana #{week}: volume de #{total.round(1)}km passa do limite de #{ceiling}km"
    end
  end
end
