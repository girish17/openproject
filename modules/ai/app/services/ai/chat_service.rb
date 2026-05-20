module Ai
  class ChatService
    MAX_TOOL_CALL_LOOPS = 5

    def initialize(conversation:, user: User.current)
      @conversation = conversation
      @user = user
      @llm = Ai::LlmClient.new
    end

    def call
      messages = build_messages
      tools = tool_definitions
      tool_objects = tool_registry

      loop_count = 0

      begin
        @llm.chat(messages, tools:, stream: true) do |event|
          case event[:type]
          when :token
            yield({ type: :token, content: event[:content] })
          when :done
            @last_response = event[:response]
          end
        end

        tool_calls = @last_response&.dig("message", "tool_calls")
        break if tool_calls.blank? || loop_count >= MAX_TOOL_CALL_LOOPS

        yield({ type: :tool_calls_start })

        messages << { role: "assistant", content: @last_response.dig("message", "content") || "", tool_calls: }

        tool_calls.each do |tc|
          tool_name = tc.dig("function", "name")
          arguments = JSON.parse(tc.dig("function", "arguments") || "{}") rescue {}

          yield({ type: :tool_call, name: tool_name, arguments: })

          tool_class = tool_objects[tool_name]
          if tool_class
            result = tool_class.execute(arguments.with_indifferent_access)
            yield({ type: :tool_result, name: tool_name, result: })
            messages << { role: "tool", content: result.to_json, tool_call_id: tc["id"] }
          end
        end

        yield({ type: :tool_calls_end })
        loop_count += 1
      end while tool_calls.present? && loop_count < MAX_TOOL_CALL_LOOPS

      final_content = @last_response&.dig("message", "content") || ""

      @conversation.messages.create!(role: :assistant, content: final_content)

      yield({ type: :done, content: final_content })
    rescue Ai::LlmClient::Error => e
      yield({ type: :error, message: "AI service error: #{e.message}" })
    rescue StandardError => e
      yield({ type: :error, message: "An unexpected error occurred: #{e.message}" })
    end

    private

    def build_messages
      system_prompt = build_system_prompt
      history = @conversation.messages.map do |msg|
        { role: msg.role, content: msg.content || "" }
      end
      [{ role: "system", content: system_prompt }] + history
    end

    def build_system_prompt
      now = Time.zone.now

      <<~PROMPT
        You are Yojana AI, an intelligent assistant for Yojana — an open-source project management platform.
        You help users manage their projects, tasks, and portfolios.

        Current user: #{@user.name} (#{@user.mail})
        Current time: #{now.strftime("%Y-%m-%d %H:%M %Z")}

        You have access to tools that let you search, create, and update work packages.
        When a user asks you to do something, use the appropriate tool.
        Always confirm what you've done and provide relevant URLs when creating or finding items.

        If the user asks about "my tasks" or "my work", use the get_user_tasks tool.
        Be concise but helpful. Use markdown formatting for clarity.
      PROMPT
    end

    def tool_definitions
      tool_registry.values.map(&:tool_spec)
    end

    def tool_registry
      @tool_registry ||= {
        "search_work_packages" => Ai::Tools::SearchWorkPackages.new,
        "create_work_package" => Ai::Tools::CreateWorkPackage.new,
        "update_work_package" => Ai::Tools::UpdateWorkPackage.new,
        "get_project_info" => Ai::Tools::GetProjectInfo.new,
        "get_user_tasks" => Ai::Tools::GetUserTasks.new,
        "list_projects" => Ai::Tools::ListProjects.new
      }
    end
  end
end
