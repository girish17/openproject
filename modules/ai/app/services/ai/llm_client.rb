module Ai
  class LlmClient
    Error = Class.new(StandardError)
    ConnectionError = Class.new(Error)
    ModelNotFoundError = Class.new(Error)

    def initialize(endpoint: nil, model: nil)
      @endpoint = (endpoint || ENV["OLLAMA_HOST"].presence || setting.ollama_endpoint).chomp("/")
      @model = model || setting.default_model
    end

    def chat(messages, tools: nil, stream: nil, &block)
      payload = { model: @model, messages:, stream: stream ? true : false }
      payload[:tools] = tools if tools

      if stream && block
        stream_chat(payload, &block)
      else
        response = with_timeout_handling { connection.post("/api/chat", payload.to_json) }
        handle_errors(response)
        response.body.is_a?(Hash) ? response.body : JSON.parse(response.body)
      end
    end

    def embed(text)
      response = with_timeout_handling { connection.post("/api/embed", { model: @model, input: text }.to_json) }
      handle_errors(response)
      body = response.body.is_a?(Hash) ? response.body : JSON.parse(response.body)
      body.fetch("embeddings", [])
    end

    def available?
      response = connection.get("/api/tags")
      response.success?
    rescue StandardError
      false
    end

    private

    def stream_chat(payload)
      full_response = { "message" => { "role" => "assistant", "content" => "", "tool_calls" => [] } }

      with_timeout_handling do
        connection.post("/api/chat", payload.to_json) do |req|
          req.options.on_data = ->(chunk, _bytes, _env) do
            next if chunk.strip.empty?
            parsed = JSON.parse(chunk) rescue next
            msg = parsed["message"] || {}

            if (content = msg["content"])
              full_response["message"]["content"] += content
              yield({ type: :token, content: })
            end

            if (tool_calls = msg["tool_calls"])
              full_response["message"]["tool_calls"] = tool_calls
            end

            if parsed["done"]
              yield({ type: :done, response: full_response })
            end
          end
        end
      end
    end

    def connection
      @connection ||= Faraday.new(@endpoint) do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
        f.options.timeout = 300
        f.options.open_timeout = 10
      end
    end

    def handle_errors(response)
      raise ConnectionError, "Ollama returned #{response.status}" unless response.success?
    end

    def with_timeout_handling
      yield
    rescue Faraday::TimeoutError
      raise ConnectionError, "Ollama took too long to respond (300s timeout). The model may still be loading from cold start — try again."
    end

    def setting
      @setting ||= Ai::Setting.instance
    end
  end
end
