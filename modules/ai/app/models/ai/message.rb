module Ai
  class Message < ApplicationRecord
    self.table_name = "ai_messages"

    belongs_to :conversation, class_name: "Ai::Conversation"

    enum :role, { user: 0, assistant: 1, system: 2, tool: 3 }

    validates :role, presence: true
  end
end
