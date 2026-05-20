module Ai
  module Agents
    class Base
      attr_reader :agent, :user

      def initialize(agent)
        @agent = agent
        @user = agent.user
      end

      def execute
        raise NotImplementedError
      end

      def self.available_types
        {
          "custom" => "Custom Agent",
          "daily_summary" => "Daily Summary"
        }
      end

      def self.for(agent)
        case agent.agent_type
        when "custom"
          CustomAgent.new(agent)
        when "daily_summary"
          DailySummaryAgent.new(agent)
        else
          new(agent)
        end
      end
    end
  end
end
