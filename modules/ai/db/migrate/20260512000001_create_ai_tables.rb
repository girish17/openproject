class CreateAiTables < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, foreign_key: true
      t.string :title
      t.timestamps
    end

    create_table :ai_messages do |t|
      t.references :conversation, null: false, foreign_key: { to_table: :ai_conversations }
      t.integer :role, null: false, default: 0
      t.text :content
      t.jsonb :tool_calls
      t.string :tool_call_id
      t.timestamps
    end

    create_table :ai_settings do |t|
      t.string :ollama_endpoint, null: false, default: "http://localhost:11434"
      t.string :default_model, null: false, default: "llama3.2:3b"
      t.integer :max_tokens, null: false, default: 2048
      t.float :temperature, null: false, default: 0.7
      t.timestamps
    end

    add_index :ai_conversations, :created_at
    add_index :ai_messages, %i[conversation_id created_at]
  end
end
