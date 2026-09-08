require "net/http"
require "json"

# Ponto unico de chamada da API da Gemini -- evita que os servicos de IA
# divirjam entre si de modelo ou configuracao.
class GeminiClient
  MODEL = "gemini-2.5-flash"
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/#{MODEL}:generateContent".freeze
  READ_TIMEOUT = 90
  # O modelo suporta ate 65.536 tokens de saida. Um plano de iniciante tem 27
  # treinos com blocos e instrucoes, e 16.000 nao davam conta.
  MAX_OUTPUT_TOKENS = 48_000

  class Error < StandardError; end

  # response_schema garante a estrutura da resposta -- responseMimeType
  # sozinho e so uma dica forte, nao garantia.
  def self.generate_json(prompt, response_schema:, temperature: 0.2, max_output_tokens: MAX_OUTPUT_TOKENS)
    raise Error, "Chave da API Gemini não configurada" if ENV["GEMINI_API_KEY"].blank?

    body = {
      contents: [ { parts: [ { text: prompt } ] } ],
      generationConfig: {
        temperature: temperature,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: max_output_tokens,
        responseMimeType: "application/json",
        responseSchema: response_schema,
        # No 2.5-flash o "thinking" vem ligado e gasta o MESMO orcamento de
        # maxOutputTokens -- um plano de 27 treinos truncava no meio do JSON
        # por causa disso. Aqui nao ha ganho em raciocinio livre: os limites
        # ja vem calculados em Ruby e o schema fixa a estrutura.
        thinkingConfig: { thinkingBudget: 0 }
      }
    }

    parsed = post(body)
    finish_reason = parsed.dig("candidates", 0, "finishReason")

    if finish_reason == "MAX_TOKENS"
      raise Error, "Resposta truncada pela Gemini (limite de #{max_output_tokens} tokens atingido)"
    end

    content = parsed.dig("candidates", 0, "content", "parts", 0, "text")
    raise Error, "Resposta vazia da API Gemini (finishReason: #{finish_reason})" if content.blank?

    JSON.parse(content)
  rescue JSON::ParserError => e
    raise Error, "JSON inválido vindo da Gemini: #{e.message}"
  end

  def self.post(body)
    uri = URI("#{API_URL}?key=#{ENV['GEMINI_API_KEY']}")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: READ_TIMEOUT) do |http|
      http.request(request)
    end

    parsed = JSON.parse(response.body)
    raise Error, "Erro da API Gemini: #{parsed['error']['message']}" if parsed["error"]

    parsed
  end
  private_class_method :post
end
