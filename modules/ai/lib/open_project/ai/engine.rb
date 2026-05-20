module OpenProject::Ai
  class Engine < ::Rails::Engine
    engine_name :openproject_ai

    include OpenProject::Plugins::ActsAsOpEngine

    register "openproject-ai",
             author_url: "https://yojana.dev",
             bundled: true,
             settings: {} do
      project_module :ai_assistant do
        permission :view_ai_assistant,
                   {},
                   permissible_on: :project,
                   contract_actions: { ai: %i[read] }
        permission :manage_ai_assistant,
                   {},
                   permissible_on: :project,
                   contract_actions: { ai: %i[create update destroy] }
      end
    end

    initializer "ai.feature_decisions" do
      OpenProject::FeatureDecisions.add :ai_chat_assistant,
                                        description: "Enables the AI chat assistant with tool calling.",
                                        force_active: true

      OpenProject::FeatureDecisions.add :ai_inline_features,
                                        description: "Enables inline AI features: NL search, smart autofill, summarization.",
                                        force_active: true

      OpenProject::FeatureDecisions.add :ai_agents,
                                        description: "Enables scheduled AI agents and advanced automation.",
                                        force_active: true
    end

    initializer "ai.register_mimetypes" do
      Mime::Type.register("text/event-stream", :sse)
    end

    config.to_prepare do
      Ai::Setting.ensure_singleton if ActiveRecord::Base.connection.data_source_exists?("ai_settings")
    end

    config.to_prepare do
      require "open_project/ai/hooks"
    end
  end
end
