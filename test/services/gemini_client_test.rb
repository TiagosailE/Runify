require "test_helper"

class GeminiClientTest < ActiveSupport::TestCase
  test "generate_json manda a chave no header, nunca na url" do
    original_key = ENV["GEMINI_API_KEY"]
    ENV["GEMINI_API_KEY"] = "chave-de-teste"

    fake_response = Object.new
    fake_response.define_singleton_method(:body) do
      {
        candidates: [
          { content: { parts: [ { text: '{"ok":true}' } ] }, finishReason: "STOP" }
        ]
      }.to_json
    end

    fake_http = Object.new
    captured_request = nil
    fake_http.define_singleton_method(:request) do |request|
      captured_request = request
      fake_response
    end

    start_stub = ->(*_args, **_kwargs, &block) { block.call(fake_http) }

    Net::HTTP.stub :start, start_stub do
      GeminiClient.generate_json("prompt", response_schema: { type: "object" })
    end

    assert_equal "chave-de-teste", captured_request["x-goog-api-key"]
    assert_no_match(/key=/, captured_request.uri.to_s)
  ensure
    ENV["GEMINI_API_KEY"] = original_key
  end
end
