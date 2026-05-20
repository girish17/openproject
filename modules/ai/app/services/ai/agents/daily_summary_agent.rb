module Ai
  module Agents
    class DailySummaryAgent < Base
      def execute
        project_scope = agent.project ? " in project #{agent.project.name}" : ""
        since = 24.hours.ago

        recent_wps = WorkPackage.visible(user)
        recent_wps = recent_wps.where(project: agent.project) if agent.project
        recent_wps = recent_wps.where("created_at >= ? OR updated_at >= ?", since, since)
          .limit(10)

        context = if recent_wps.any?
          recent_wps.map { |wp| "- #{wp.type.name} ##{wp.id}: #{wp.subject} (#{wp.status.name})" }.join("\n")
        else
          "No recent activity."
        end

        prompt = <<~PROMPT
          #{self.class.prescribed_prompt}

          Recent work package activity#{project_scope} (last 24 hours):
          #{context}

          Provide a concise summary of what happened.
        PROMPT

        llm = Ai::LlmClient.new
        response = llm.chat([{ role: "user", content: prompt }])
        response.is_a?(Hash) ? response.dig("message", "content") : response
      end

      def self.prescribed_prompt
        <<~PROMPT
          You are a daily summary agent for Yojana project management.
          Summarize recent work package activity in a concise, useful way.
          Highlight new items, status changes, and items that need attention.
        PROMPT
      end
    end
  end
end
