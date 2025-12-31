require 'net/http'
require 'json'

class AiTrainingService
  GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'
  
  def initialize(user)
    @user = user
  end

  def generate_training_plan
    raise "Chave da API Gemini não configurada" unless ENV['GEMINI_API_KEY'].present?
    
    prompt = build_prompt
    response = call_gemini_api(prompt)
    parse_and_create_plan(response)
  rescue => e
    Rails.logger.error "Erro em generate_training_plan: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  def build_prompt
    recent_activities = @user.activities.order(start_date: :desc).limit(10)
    
    activities_summary = if recent_activities.any?
      recent_activities.map do |activity|
        "- #{activity.formatted_date}: #{activity.name}, #{activity.distance_km}km em #{activity.duration_formatted}, pace: #{activity.pace_per_km}"
      end.join("\n")
    else
      "Nenhuma atividade registrada ainda"
    end

    available_days_raw = @user.available_days || [1, 3, 5, 7]
    available_days = Array(available_days_raw).map(&:to_i).select { |d| d.between?(1,7) }
    available_days = [1, 3, 5, 7] if available_days.empty?
    days_text = available_days.map { |d| ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'][d - 1] }.join(', ')

    <<~PROMPT
      Você é um treinador profissional de corrida. Analise os dados do atleta e crie um plano de treino semanal personalizado.

      DADOS DO ATLETA:
      - Nome: #{@user.username || 'Atleta'}
      - Idade: #{@user.age || 'Não informado'} anos
      - Peso: #{@user.weight || 'Não informado'}kg
      - Altura: #{@user.height || 'Não informado'}cm
      - Objetivo: #{@user.goal || 'Melhorar performance'}
      - Dias disponíveis para treinar: #{days_text}

      ATIVIDADES RECENTES (últimas 10):
      #{activities_summary}

      INSTRUÇÕES:
      1. Analise o nível atual do atleta baseado nas atividades
      2. Considere o objetivo dele
      3. Crie um plano de 4 semanas com treinos APENAS nos dias: #{available_days.join(', ')}
      4. Varie os tipos de treino: Corrida Leve, Tempo Run, Intervalado, Longão
      5. SEJA MUITO ESPECÍFICO nas instruções de cada treino

      CRÍTICO: Retorne APENAS o JSON, sem nenhum texto antes ou depois, sem markdown, sem explicações.
      
      Formato JSON obrigatório:
      {
        "analysis": "Breve análise do atleta",
        "plan_duration_weeks": 4,
        "weekly_volume_km": 25,
        "workouts": [
          {
            "week": 1,
            "day": #{available_days[0]},
            "type": "Corrida Leve",
            "distance_km": 5,
            "duration_minutes": 30,
            "pace": "6:00-6:30",
            "description": "Corrida leve para começar",
            "instructions": "Aquecimento: 5 min trote leve\\n\\nParte principal: 20 min corrida leve (pace 6:00-6:30)\\n\\nDesaquecimento: 5 min caminhada + alongamento"
          }
        ]
      }

      IMPORTANTE: 
      - Use APENAS os dias #{available_days.join(', ')} 
      - Retorne SOMENTE o JSON, nada mais
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
        temperature: 0.4,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 8192,
        responseMimeType: "application/json"
      }
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    parsed_response = JSON.parse(response.body)
    
    Rails.logger.info "Gemini API Response: #{parsed_response.inspect}"
    
    if parsed_response['error']
      raise "Erro da API Gemini: #{parsed_response['error']['message']}"
    end
    
    parsed_response
  end

  def parse_and_create_plan(gemini_response)
    content = gemini_response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    
    raise "Resposta vazia da API" if content.nil? || content.empty?
    
    Rails.logger.info "=== Conteúdo Bruto da Gemini ==="
    Rails.logger.info content
    Rails.logger.info "=== Fim do Conteúdo ==="

    plan_data = extract_json_from_content(content)
    
    raise "JSON não encontrado na resposta. Conteúdo: #{content[0..500]}" unless plan_data
    
    validate_plan_data(plan_data)
    
    plan_duration_weeks = plan_data['plan_duration_weeks'].to_i
    plan_duration_weeks = 4 if plan_duration_weeks <= 0

    training_plan = @user.training_plans.create!(
      goal: @user.goal,
      status: 'active',
      start_date: Date.today,
      end_date: Date.today + plan_duration_weeks.weeks,
      total_weeks: plan_duration_weeks,
      plan_data: plan_data
    )

    create_workouts(training_plan, plan_data)
    
    training_plan
  rescue JSON::ParserError => e
    Rails.logger.error "Erro ao fazer parse do JSON: #{e.message}"
    Rails.logger.error "Content: #{content}"
    raise "Erro ao processar resposta da IA: Formato JSON inválido"
  end

  def extract_json_from_content(content)

    clean_content = content.gsub(/```json|```/m, '').strip

    json_match = clean_content.match(/\{.*\}/m)
    return JSON.parse(json_match[0]) if json_match

    begin
      return JSON.parse(clean_content)
    rescue JSON::ParserError

    end

    first_brace = content.index('{')
    last_brace = content.rindex('}')
    
    if first_brace && last_brace && first_brace < last_brace
      json_str = content[first_brace..last_brace]
      return JSON.parse(json_str)
    end
    
    nil
  rescue JSON::ParserError
    nil
  end

  def validate_plan_data(plan_data)
    raise "Estrutura de plano inválida" unless plan_data.is_a?(Hash)
    raise "Campo 'workouts' ausente" unless plan_data['workouts'].is_a?(Array)
    raise "Nenhum treino foi gerado" if plan_data['workouts'].empty?
    
    plan_data['workouts'].each_with_index do |workout, index|
      week = workout['week'].to_i
      day = workout['day'].to_i
      
      raise "Treino ##{index + 1}: semana inválida (#{week})" if week <= 0
      raise "Treino ##{index + 1}: dia inválido (#{day})" if day <= 0 || day > 7
    end
  end

  def create_workouts(training_plan, plan_data)
    plan_data['workouts'].each do |workout_data|
      week = workout_data['week'].to_i
      day = workout_data['day'].to_i
      
      scheduled_date = Date.today + (week - 1).weeks + (day - 1).days
      distance = workout_data['distance_km'].to_f
      duration_seconds = workout_data['duration_minutes'].to_i * 60

      training_plan.workouts.create!(
        week_number: week,
        day_of_week: day,
        scheduled_date: scheduled_date,
        workout_type: workout_data['type'].to_s,
        distance: distance,
        duration: duration_seconds,
        pace: workout_data['pace'].to_s,
        description: workout_data['description'].to_s,
        instructions: workout_data['instructions'].to_s,
        workout_details: workout_data,
        status: 'pending'
      )
    end
  end
end