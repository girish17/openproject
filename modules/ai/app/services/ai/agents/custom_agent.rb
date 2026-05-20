module Ai
  module Agents
    class CustomAgent < Base
      def execute
        llm = Ai::LlmClient.new
        response = llm.chat([
          { role: "system", content: agent.prompt },
          { role: "user", content: "Execute your task based on the instructions above." }
        ])

        response.is_a?(Hash) ? response.dig("message", "content") : response
      end
    end
  end
end
