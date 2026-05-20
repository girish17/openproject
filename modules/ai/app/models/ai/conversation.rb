module Ai
  class Conversation < ApplicationRecord
    self.table_name = "ai_conversations"

    belongs_to :user
    belongs_to :project, optional: true
    has_many :messages, -> { order(created_at: :asc) }, class_name: "Ai::Message", foreign_key: :conversation_id,
             dependent: :destroy

    validates :title, length: { maximum: 255 }

    scope :for_user, ->(user) { where(user:) }
    scope :recent, -> { order(updated_at: :desc) }
  end
end
