# check_models.rb
require 'net/http'
require 'json'
require 'uri'
require 'dotenv/load' # Tenta carregar o .env se tiver a gem instalada

api_key = ENV['GEMINI_API_KEY']

# Se não carregar via dotenv (caso não tenha a gem no script avulso), 
# tente pegar direto ou avise.
if api_key.nil? || api_key.empty?
  puts "⚠️  AVISO: Chave GEMINI_API_KEY não encontrada no ENV."
  puts "Por favor, cole sua API Key aqui e pressione ENTER:"
  api_key = gets.chomp
end

puts "\n🔍 Consultando modelos disponíveis na API (v1beta)..."
puts "Usando chave: #{api_key[0..5]}...#{api_key[-4..-1]}"

uri = URI("https://generativelanguage.googleapis.com/v1beta/models?key=#{api_key}")
response = Net::HTTP.get_response(uri)

if response.is_a?(Net::HTTPSuccess)
  data = JSON.parse(response.body)
  models = data['models']
  
  puts "\n✅ SUCESSO! Modelos disponíveis:"
  puts "-" * 50
  
  # Filtra apenas os que geram conteúdo (chat/texto)
  generate_models = models.select { |m| m['supportedGenerationMethods'].include?('generateContent') }
  
  generate_models.each do |model|
    puts "Nome: #{model['name']}" # Ex: models/gemini-1.5-flash
    puts "Versão: #{model['version']}"
    puts "Descrição: #{model['description'][0..100]}..."
    puts "-" * 50
  end

  puts "\n💡 DICA PARA O SEU CÓDIGO:"
  recommendation = generate_models.find { |m| m['name'].include?('flash') } || generate_models.first
  if recommendation
    puts "No arquivo 'ai_training_service.rb', use EXATAMENTE este nome:"
    puts "GEMINI_MODEL_NAME = '#{recommendation['name'].sub('models/', '')}'"
  end

else
  puts "\n❌ ERRO NA REQUISIÇÃO:"
  puts "Status: #{response.code}"
  puts "Body: #{response.body}"
end