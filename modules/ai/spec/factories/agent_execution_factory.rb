# frozen_string_literal: true

FactoryBot.define do
  factory :ai_agent_execution, class: "Ai::AgentExecution" do
    association :agent, factory: :ai_agent
    status { :pending }

    trait :running do
      status { :running }
      started_at { Time.current }
    end

    trait :completed do
      status { :completed }
      started_at { Time.current - 10.minutes }
      completed_at { Time.current }
      result { "Task completed successfully." }
    end

    trait :failed do
      status { :failed }
      started_at { Time.current - 10.minutes }
      completed_at { Time.current }
      error_message { "StandardError: Something went wrong" }
    end
  end
end
