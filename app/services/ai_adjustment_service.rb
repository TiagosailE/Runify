require 'net/http'
require 'json'

class AiAdjustmentService
  GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent'

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
    
    prompt = build_adjustment_prompt(completed_workouts)
    response = call_gemini_api(prompt)
    apply_adjustments(response, current_week)
  end

  private

  def build_adjustment_prompt(completed_workouts)
    feedback_summary = completed_workouts.map do |workout|
      feedback = workout.workout_details&.dig('user_feedback')
      difficulty = feedback&.dig('difficulty') || 'não informado'
      
      "- #{workout.workout_type}: #{workout.distance_km}km, pace #{workout.pace}
         Dificuldade reportada: #{difficulty}
         Instruções: #{workout.instructions&.first(100)}..."
    end.join("\n")

    <<~PROMPT
      Você é um treinador de corrida analisando o desempenho do atleta.

      PERFIL DO ATLETA:
      - Objetivo: #{@user.goal}
      - Semana atual: #{@training_plan.current_week} de #{@training_plan.total_weeks}

      TREINOS DA SEMANA PASSADA (REALIZADOS):
      #{feedback_summary}

      ANÁLISE NECESSÁRIA:
      1. Se muitos treinos foram "fáceis" → aumentar intensidade/distância em 5-10%
      2. Se muitos treinos foram "difíceis" → reduzir intensidade/distância em 10-15%
      3. Se balanceado ("médio") → manter progressão normal

      RESPONDA APENAS com JSON:
      {
        "analysis": "Análise breve do desempenho",
        "adjustment_type": "increase|decrease|maintain",
        "adjustment_percentage": 10,
        "recommendations": [
          "Recomendação 1",
          "Recomendação 2"
        ]
      }
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
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048,
      }
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end

  def apply_adjustments(gemini_response, current_week)
    content = gemini_response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    return unless content
    
    clean_content = content.gsub(/```json|```/, '').strip
    adjustment_data = JSON.parse(clean_content)
    
    adjustment_type = adjustment_data['adjustment_type']
    percentage = adjustment_data['adjustment_percentage'].to_f / 100
    
    remaining_workouts = @training_plan.workouts.where('week_number >= ?', current_week)
    
    remaining_workouts.each do |workout|
      next if workout.completed?
      
      case adjustment_type
      when 'increase'
        workout.distance = (workout.distance * (1 + percentage)).round(2)
        workout.duration = (workout.duration * (1 + percentage)).to_i
      when 'decrease'
        workout.distance = (workout.distance * (1 - percentage)).round(2)
        workout.duration = (workout.duration * (1 - percentage)).to_i
      end
      
      workout.workout_details = workout.workout_details.merge({
        'ai_adjustment' => {
          'date' => Time.current,
          'type' => adjustment_type,
          'percentage' => percentage * 100,
          'reason' => adjustment_data['analysis']
        }
      })
      
      workout.save
    end
    
    Rails.logger.info "AI Adjustment applied: #{adjustment_type} by #{percentage * 100}%"
  end
end