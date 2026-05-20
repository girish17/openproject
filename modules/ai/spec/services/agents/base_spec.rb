# frozen_string_literal: true

require "billy"
require "spec_helper"

RSpec.describe Ai::Agents::Base do
  let(:agent) { build(:ai_agent) }
  subject { described_class.new(agent) }

  describe "#initialize" do
    it "stores the agent" do
      expect(subject.agent).to eq(agent)
    end

    it "stores the user from the agent" do
      expect(subject.user).to eq(agent.user)
    end
  end

  describe "#execute" do
    it "raises NotImplementedError" do
      expect { subject.execute }.to raise_error(NotImplementedError)
    end
  end

  describe ".available_types" do
    it "returns a hash of type identifiers to labels" do
      types = described_class.available_types
      expect(types).to include("custom")
      expect(types).to include("daily_summary")
    end
  end

  describe ".for" do
    let(:custom_agent) { build(:ai_agent, agent_type: "custom") }
    let(:summary_agent) { build(:ai_agent, :daily_summary) }
    let(:unknown_agent) { build(:ai_agent, agent_type: "unknown") }

    it "returns a CustomAgent for custom type" do
      expect(described_class.for(custom_agent)).to be_a(Ai::Agents::CustomAgent)
    end

    it "returns a DailySummaryAgent for daily_summary type" do
      expect(described_class.for(summary_agent)).to be_a(Ai::Agents::DailySummaryAgent)
    end

    it "returns a Base instance for unknown type" do
      expect(described_class.for(unknown_agent)).to be_a(described_class)
    end
  end
end
