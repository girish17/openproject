module Ai
  class SearchService
    def initialize(query, user: User.current, project: nil)
      @query = query
      @user = user
      @project = project
    end

    def call
      return fallback_search unless llm_available?

      prompt = build_prompt
      response = llm.chat([{ role: "system", content: prompt }, { role: "user", content: @query }])
      parse_response(response)
    rescue Ai::LlmClient::Error
      fallback_search
    end

    private

    def build_prompt
      project_context = @project ? "The user is in project: #{@project.name}" : "No specific project context"

      <<~PROMPT
        You are a search assistant for Yojana, a project management tool.
        #{project_context}

        Convert the user's natural language query into structured search parameters.
        Respond with ONLY a JSON object:
        {
          "q": "search keywords",
          "scope": "work_packages" | "projects" | "all",
          "filters": {
            "status": "open" | "closed" | null,
            "assignee": "me" | null,
            "priority": "high" | "medium" | "low" | null,
            "type": "task" | "bug" | "feature" | "epic" | null
          }
        }
        Use null for unspecified filters. Extract the core search terms into "q".
      PROMPT
    end

    def parse_response(response)
      content = response.is_a?(Hash) ? response.dig("message", "content") : response
      return fallback_search if content.blank?

      JSON.parse(content).deep_symbolize_keys
    rescue JSON::ParserError
      fallback_search
    end

    def fallback_search
      { q: @query, scope: "all", filters: {} }
    end

    def llm
      @llm ||= Ai::LlmClient.new
    end

    def llm_available?
      llm.available?
    rescue StandardError
      false
    end
  end
end
