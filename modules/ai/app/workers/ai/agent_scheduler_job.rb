module Ai
  class AgentSchedulerJob < ApplicationJob
    queue_with_priority :low

    def perform
      return unless OpenProject::FeatureDecisions.ai_agents_active?

      Ai::Agent.active.find_each do |agent|
        next unless agent.due?

        Rails.logger.info { "AI Agents: Enqueuing agent ##{agent.id} (#{agent.name})" }
        agent.enqueue!
      end
    end
  end
end
