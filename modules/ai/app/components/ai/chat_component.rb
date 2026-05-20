module Ai
  class ChatComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers

    def render?
      OpenProject::FeatureDecisions.ai_chat_assistant_active? && User.current.logged?
    end
  end
end
