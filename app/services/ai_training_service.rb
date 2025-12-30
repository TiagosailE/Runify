require 'net/http'
require 'json'

class AiTrainingService
  GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent'

  def initialize(user)
    @user = user
  end

  def generate_training_plan
    raise "Chave da API Gemini não configurada" unless ENV['GEMINI_API_KEY'].present?
    prompt_data = build_request_body
    response = call_gemini_api(prompt_data)
    parse_and_create_plan(response)
  end

  private

  def build_request_body
    recent_activities = @user.activities.order(start_date: :desc).limit(10)
    
    activities_summary = if recent_activities.any?
      recent_activities.map do |activity|
        "- #{activity.formatted_date}: #{activity.name}, #{activity.distance_km}km em #{activity.duration_formatted}, pace: #{activity.pace_per_km}"
      end.join("\n")
    else
      "Nenhuma atividade registrada ainda"
    end

    user_data = <<~TEXT
      DADOS DO ATLETA:
      - Nome: #{@user.username || 'Atleta'}
      - Idade: #{@user.age || 'Não informado'} anos
      - Peso: #{@user.weight || 'Não informado'}kg
      - Altura: #{@user.height || 'Não informado'}cm
      - Objetivo: #{@user.goal || 'Melhorar performance'}

      ATIVIDADES RECENTES (últimas 10):
      #{activities_summary}
    TEXT
    
    system_instruction = <<~TEXT
      Você é um treinador de corrida de elite com conhecimento em fisiologia do exercício.
      Sua tarefa é criar planos de treino estruturados em formato JSON.
      
      Regras:
      1. Analise o nível do atleta e crie um plano de 4 semanas.
      2. Varie os estímulos: Rodagem (leve), Intervalado (velocidade), Tempo Run (limiar) e Longão (resistência).
      3. O JSON deve ser estritamente válido. Sem markdown (```json), apenas o objeto puro.
    TEXT

    prompt_text = <<~TEXT
      #{user_data}

      Com base nos dados acima, gere o JSON de treino seguindo este schema exato:
      {
        "analysis": "string",
        "plan_duration_weeks": 4,
        "weekly_volume_km": integer,
        "workouts": [
          {
            "week": integer,
            "day": integer (1-7),
            "type": "string",
            "distance_km": float,
            "duration_minutes": integer,
            "pace": "string (min/km)",
            "description": "string",
            "instructions": "string"
          }
        ]
      }
    TEXT

    {
      system_instruction: {
        parts: { text: system_instruction }
      },
      contents: [{
        parts: [{ text: prompt_text }]
      }],
      generationConfig: {
        temperature: 0.4,
        response_mime_type: "application/json" 
      }
    }
  end

  def call_gemini_api(body_hash)
    uri = URI("#{GEMINI_API_URL}?key=#{ENV['GEMINI_API_KEY']}")
    
    retries = 0
    max_retries = 3

    begin
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = body_hash.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
      if response.code == '429'
        raise "QUOTA_HIT"
      end

      parsed_response = JSON.parse(response.body)
      
      if parsed_response['error']
        error_msg = parsed_response['error']['message']
        Rails.logger.error "Gemini API Error: #{error_msg}"

        if error_msg.downcase.include?('quota') || error_msg.downcase.include?('limit')
          raise "QUOTA_HIT"
        else
          raise "Erro da API Gemini: #{error_msg}"
        end
      end
      
      parsed_response

    rescue RuntimeError => e
      if e.message == "QUOTA_HIT" && retries < max_retries
        retries += 1
        sleep_time = 2 * retries
        Rails.logger.warn "Tentando novamente em #{sleep_time} segundos... (Tentativa #{retries})"
        sleep(sleep_time)
        retry 
      else
        if e.message == "QUOTA_HIT"
          raise "O sistema está sobrecarregado no momento. Tente novamente em 2 minutos."
        else
          raise e
        end
      end
    end
  end

  def parse_and_create_plan(gemini_response)
    content = gemini_response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    
    raise "Resposta vazia da API" if content.nil? || content.empty?
    clean_content = content.gsub(/```json|```/, '').strip
    
    begin
      plan_data = JSON.parse(clean_content)
    rescue JSON::ParserError
      json_match = clean_content.match(/\{.*\}/m)
      raise "Formato inválido recebido da IA" unless json_match
      plan_data = JSON.parse(json_match[0])
    end

    ActiveRecord::Base.transaction do
      @user.training_plans.active.update_all(status: 'cancelled')

      training_plan = @user.training_plans.create!(
        goal: @user.goal,
        status: 'active',
        start_date: Date.today,
        end_date: Date.today + plan_data['plan_duration_weeks'].weeks,
        total_weeks: plan_data['plan_duration_weeks'],
        plan_data: plan_data
      )

      plan_data['workouts'].each do |workout_data|
        scheduled_date = Date.today + (workout_data['week'] - 1).weeks + (workout_data['day'] - 1).days
        
        training_plan.workouts.create!(
          week_number: workout_data['week'],
          day_of_week: workout_data['day'],
          scheduled_date: scheduled_date,
          workout_type: workout_data['type'],
          distance: workout_data['distance_km'],
          duration: workout_data['duration_minutes'] * 60, 
          pace: workout_data['pace'],
          description: workout_data['description'],
          instructions: workout_data['instructions'],
          workout_details: workout_data,
          status: 'pending'
        )
      end
      
      training_plan
    end
  rescue StandardError => e
    Rails.logger.error "Erro ao processar plano: #{e.message}"
    Rails.logger.error "Conteúdo recebido: #{content}"
    raise e
  end
end