# frozen_string_literal: true

FactoryBot.define do
  factory :ai_agent, class: "Ai::Agent" do
    association :user
    name { "Test Agent" }
    prompt { "You are a helpful test agent." }
    cron_expression { "0 8 * * *" }
    agent_type { "custom" }
    active { true }

    trait :inactive do
      active { false }
    end

    trait :daily_summary do
      agent_type { "daily_summary" }
      name { "Daily Summary" }
      prompt { "Summarize daily activity." }
    end
  end
end
