require 'net/http'
require 'json'

class AiAdjustmentService
  GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent'

  def initialize(user, training_plan)
    @user = user
    @training_plan = training_plan
  end

  def analyze_and_adjust
    current_week = @training_plan.current_week
    return unless current_week > 1
    
    previous_week_workouts = @training_plan.workouts_for_week(current_week - 1)
    completed_workouts = previous_week_workouts.select(&:completed?)
    
    return if completed_workouts.empty?
    
    prompt = build_adjustment_prompt(completed_workouts, current_week)
    response = call_gemini_api(prompt)
    apply_adjustments(response, current_week)
  rescue => e
    Rails.logger.error "Erro em AiAdjustmentService: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def build_adjustment_prompt(completed_workouts, current_week)
    feedback_summary = completed_workouts.map do |workout|
      feedback = workout.workout_details&.dig('user_feedback')
      difficulty = feedback&.dig('difficulty') || 'não informado'
      notes = feedback&.dig('notes') || ''
      
      <<~WORKOUT
        - Treino: #{workout.workout_type}
          Distância planejada: #{workout.distance_km}km
          Pace planejado: #{workout.pace}
          Dificuldade reportada: #{difficulty}/5
          Observações do atleta: #{notes.present? ? notes : 'Nenhuma'}
      WORKOUT
    end.join("\n")

    completion_rate = (completed_workouts.count.to_f / @training_plan.workouts_for_week(current_week - 1).count * 100).round
    
    recent_activities = @user.activities.where('start_date >= ?', 7.days.ago).order(start_date: :desc)
    strava_summary = if recent_activities.any?
      recent_activities.map do |act|
        "- #{act.start_date.strftime('%d/%m')}: #{(act.distance/1000.0).round(2)}km, pace #{format_pace(act.average_speed)}"
      end.join("\n")
    else
      "Nenhuma atividade no Strava na última semana"
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

      ### DADOS DO STRAVA (Última Semana)
      #{strava_summary}

      ### ANÁLISE NECESSÁRIA
      
      Analise os seguintes fatores:
      1. **Dificuldade média reportada**: Se a maioria dos treinos foi muito fácil (1-2) ou muito difícil (4-5)
      2. **Taxa de conclusão**: Se o atleta pulou treinos (pode indicar sobrecarga ou falta de motivação)
      3. **Observações qualitativas**: O que o atleta escreveu nos feedbacks
      4. **Dados reais do Strava**: Compare pace planejado vs executado
      
      ### REGRAS DE AJUSTE
      
      - Se dificuldade média <= 2.5 e conclusão >= 80%: Aumentar carga em 5-10%
      - Se dificuldade média >= 4.0 ou conclusão < 60%: Reduzir carga em 10-15%
      - Se dificuldade média entre 2.5-4.0 e conclusão >= 60%: Manter progressão normal (5%)
      - Se há observações de dor/lesão: Reduzir carga e sugerir descanso
      - Considerar progressão gradual (regra dos 10% máximo)
      
      ### FORMATO DE RESPOSTA
      
      Retorne APENAS este JSON válido:
      
      ```json
      {
        "analysis": "Análise técnica do desempenho da semana passada (máximo 80 palavras)",
        "adjustment_type": "increase|decrease|maintain",
        "adjustment_percentage": 10,
        "reasoning": "Justificativa clara do ajuste baseado nos dados",
        "recommendations": [
          "Primeira recomendação específica",
          "Segunda recomendação específica"
        ],
        "red_flags": []
      }
      ```
      
      **IMPORTANTE:**
      - `adjustment_type` deve ser: "increase", "decrease" ou "maintain"
      - `adjustment_percentage` deve ser um número entre -20 e 20
      - `red_flags` deve conter alertas como "possível overtraining", "risco de lesão" se aplicável
      - Seja conservador: sempre priorize saúde sobre performance
    PROMPT
  end

  def call_gemini_api(prompt)
    uri = URI("#{GEMINI_API_URL}?key=#{ENV['GEMINI_API_KEY']}")
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    
    request.body = {
      contents: [{
        parts: [{
          text: prompt
        }]
      }],
      generationConfig: {
        temperature: 0.3,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 4096,
        responseMimeType: "application/json"
      }
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 60) do |http|
      http.request(request)
    end

    parsed = JSON.parse(response.body)
    
    if parsed['error']
      raise "Erro da API Gemini: #{parsed['error']['message']}"
    end
    
    parsed
  end

  def apply_adjustments(gemini_response, current_week)
    content = gemini_response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    return unless content
    
    clean_content = content.gsub(/```json|```/m, '').strip
    adjustment_data = JSON.parse(clean_content)
    
    adjustment_type = adjustment_data['adjustment_type']
    percentage = adjustment_data['adjustment_percentage'].to_f / 100.0
    
    remaining_workouts = @training_plan.workouts.where('week_number >= ? AND status = ?', current_week, 'pending')
    
    adjusted_count = 0
    
    remaining_workouts.each do |workout|
      original_distance = workout.distance
      original_duration = workout.duration
      
      case adjustment_type
      when 'increase'
        workout.distance = (workout.distance * (1 + percentage)).round(2)
        workout.duration = (workout.duration * (1 + percentage)).to_i
      when 'decrease'
        workout.distance = (workout.distance * (1 - percentage.abs)).round(2)
        workout.duration = (workout.duration * (1 - percentage.abs)).to_i
      when 'maintain'
        workout.distance = (workout.distance * 1.05).round(2)
        workout.duration = (workout.duration * 1.05).to_i
      end
      
      workout.distance = [workout.distance, 1.0].max
      workout.duration = [workout.duration, 600].max
      
      workout.workout_details = (workout.workout_details || {}).merge({
        'ai_adjustment' => {
          'adjusted_at' => Time.current.iso8601,
          'type' => adjustment_type,
          'percentage' => (percentage * 100).round(1),
          'reason' => adjustment_data['analysis'],
          'recommendations' => adjustment_data['recommendations'],
          'red_flags' => adjustment_data['red_flags'],
          'original_distance' => original_distance,
          'original_duration' => original_duration
        }
      })
      
      if workout.save
        adjusted_count += 1
      end
    end
    
    Rails.logger.info "=== AI ADJUSTMENT APPLIED ==="
    Rails.logger.info "Type: #{adjustment_type}"
    Rails.logger.info "Percentage: #{(percentage * 100).round(1)}%"
    Rails.logger.info "Workouts adjusted: #{adjusted_count}"
    Rails.logger.info "Analysis: #{adjustment_data['analysis']}"
    Rails.logger.info "Red Flags: #{adjustment_data['red_flags'].join(', ')}" if adjustment_data['red_flags']&.any?
    
    if adjustment_data['red_flags']&.any?
      NotificationService.send_adjustment_alert(@user, adjustment_data)
    end
    
    true
  rescue JSON::ParserError => e
    Rails.logger.error "Erro ao fazer parse do JSON de ajuste: #{e.message}"
    false
  end

  def format_pace(speed_m_s)
    return 'N/A' unless speed_m_s && speed_m_s > 0
    pace_min_km = 1000.0 / (speed_m_s * 60)
    mins = pace_min_km.floor
    secs = ((pace_min_km - mins) * 60).round
    "#{mins}:#{secs.to_s.rjust(2, '0')}/km"
  end
end