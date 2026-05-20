class CreateAiAgentTables < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_agents do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.text :prompt, null: false
      t.string :cron_expression, null: false
      t.boolean :active, null: false, default: true
      t.string :agent_type, null: false, default: "custom"
      t.jsonb :config, default: {}
      t.timestamps
    end

    create_table :ai_agent_executions do |t|
      t.references :agent, null: false, foreign_key: { to_table: :ai_agents }
      t.integer :status, null: false, default: 0
      t.text :result
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.uuid :good_job_id
      t.timestamps
    end

    add_index :ai_agents, :active
    add_index :ai_agent_executions, %i[agent_id created_at]
    add_index :ai_agent_executions, :status
  end
end
