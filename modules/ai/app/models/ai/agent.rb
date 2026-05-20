module Ai
  class Agent < ApplicationRecord
    self.table_name = "ai_agents"

    belongs_to :user
    belongs_to :project, optional: true
    has_many :executions, class_name: "Ai::AgentExecution", foreign_key: :agent_id, dependent: :destroy

    validates :name, presence: true, length: { maximum: 255 }
    validates :prompt, presence: true
    validates :cron_expression, presence: true
    validates :agent_type, presence: true

    scope :active, -> { where(active: true) }
    scope :for_user, ->(user) { where(user:) }
    scope :recent, -> { order(updated_at: :desc) }

    def due?
      return false unless active?

      cron = Fugit::Cron.parse(cron_expression)
      return false unless cron

      last_run = executions.completed.order(created_at: :desc).first
      return true unless last_run

      next_time = cron.next_time(last_run.created_at)
      return false unless next_time

      next_time.to_t <= Time.current
    end

    def enqueue!
      Ai::AgentRunJob.perform_later(self)
    end
  end
end
