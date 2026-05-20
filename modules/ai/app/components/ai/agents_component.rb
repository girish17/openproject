module Ai
  class AgentsComponent < ApplicationComponent
    def initialize
      super
    end

    def render?
      User.current.logged? && OpenProject::FeatureDecisions.ai_agents_active?
    end
  end
end
