# frozen_string_literal: true

require "billy"
require "spec_helper"

RSpec.describe Ai::AgentExecution do
  subject { build(:ai_agent_execution) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(subject).to be_valid
    end

    it "requires a status" do
      subject.status = nil
      expect(subject).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to an agent" do
      association = described_class.reflect_on_association(:agent)
      expect(association.macro).to eq :belongs_to
    end
  end

  describe "enum status" do
    it "defines expected statuses" do
      expect(described_class.statuses).to eq(
        "pending" => 0,
        "running" => 1,
        "completed" => 2,
        "failed" => 3
      )
    end

    it "provides predicate methods" do
      expect(build(:ai_agent_execution)).to be_pending
      expect(build(:ai_agent_execution, :running)).to be_running
      expect(build(:ai_agent_execution, :completed)).to be_completed
      expect(build(:ai_agent_execution, :failed)).to be_failed
    end
  end

  describe "scopes" do
    let!(:completed) { create(:ai_agent_execution, :completed) }
    let!(:failed) { create(:ai_agent_execution, :failed) }
    let!(:pending) { create(:ai_agent_execution) }

    describe ".completed" do
      it "returns only completed executions" do
        expect(described_class.completed).to contain_exactly(completed)
      end
    end

    describe ".failed" do
      it "returns only failed executions" do
        expect(described_class.failed).to contain_exactly(failed)
      end
    end

    describe ".recent" do
      it "orders by created_at descending" do
        expect(described_class.recent.first).to eq(pending)
      end
    end
  end
end
