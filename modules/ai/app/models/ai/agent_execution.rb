module Ai
  class AgentExecution < ApplicationRecord
    self.table_name = "ai_agent_executions"

    belongs_to :agent, class_name: "Ai::Agent"
    belongs_to :good_job, class_name: "GoodJob::Job", foreign_key: :good_job_id, optional: true

    enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }

    validates :status, presence: true

    scope :recent, -> { order(created_at: :desc) }
    scope :completed, -> { where(status: :completed) }
    scope :failed, -> { where(status: :failed) }
  end
end
