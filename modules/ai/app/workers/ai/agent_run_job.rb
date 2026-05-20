module Ai
  class AgentRunJob < ApplicationJob
    queue_with_priority :default

    def perform(agent)
      return unless OpenProject::FeatureDecisions.ai_agents_active?
      return unless agent.active?

      execution = agent.executions.create!(
        status: :running,
        started_at: Time.current
      )

      begin
        runner = Ai::Agents::Base.for(agent)
        result = runner.execute

        execution.update!(
          status: :completed,
          result: result.to_s,
          completed_at: Time.current
        )

        Rails.logger.info { "AI Agents: Agent ##{agent.id} completed successfully" }
      rescue StandardError => e
        execution.update!(
          status: :failed,
          error_message: "#{e.class}: #{e.message}",
          completed_at: Time.current
        )

        Rails.logger.error { "AI Agents: Agent ##{agent.id} failed: #{e.message}" }
      end
    end
  end
end
