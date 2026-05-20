# frozen_string_literal: true

require "billy"
require "spec_helper"

RSpec.describe Ai::Agent do
  subject { build(:ai_agent) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(subject).to be_valid
    end

    it "requires a name" do
      subject.name = nil
      expect(subject).not_to be_valid
    end

    it "requires a prompt" do
      subject.prompt = nil
      expect(subject).not_to be_valid
    end

    it "requires a cron_expression" do
      subject.cron_expression = nil
      expect(subject).not_to be_valid
    end

    it "requires an agent_type" do
      subject.agent_type = nil
      expect(subject).not_to be_valid
    end

    it "limits name length to 255" do
      subject.name = "a" * 256
      expect(subject).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to a user" do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq :belongs_to
    end

    it "has many executions" do
      association = described_class.reflect_on_association(:executions)
      expect(association.macro).to eq :has_many
      expect(association.options[:dependent]).to eq :destroy
    end
  end

  describe "scopes" do
    let!(:active_agent) { create(:ai_agent, active: true) }
    let!(:inactive_agent) { create(:ai_agent, :inactive) }

    describe ".active" do
      it "returns only active agents" do
        expect(described_class.active).to contain_exactly(active_agent)
      end
    end

    describe ".for_user" do
      let(:user) { create(:user) }
      let(:other_user) { create(:user) }
      let!(:user_agent) { create(:ai_agent, user:) }
      let!(:other_agent) { create(:ai_agent, user: other_user) }

      it "returns agents for the given user" do
        expect(described_class.for_user(user)).to contain_exactly(user_agent)
      end
    end

    describe ".recent" do
      let!(:old_agent) { create(:ai_agent, updated_at: 1.day.ago) }
      let!(:new_agent) { create(:ai_agent) }

      before do
        new_agent.touch
      end

      it "orders by updated_at descending" do
        expect(described_class.recent.first).to eq(new_agent)
      end
    end
  end

  describe "#due?" do
    let(:agent) { create(:ai_agent) }

    context "when inactive" do
      let(:agent) { create(:ai_agent, :inactive) }

      it "returns false" do
        expect(agent).not_to be_due
      end
    end

    context "when never run" do
      it "returns true" do
        expect(agent).to be_due
      end
    end

    context "when last run is recent and within schedule" do
      it "returns false" do
        Timecop.freeze(Time.zone.parse("2026-05-16 06:00:00")) do
          agent = create(:ai_agent)
          create(:ai_agent_execution, :completed, agent:,
                                                  created_at: 5.minutes.ago)
          expect(agent).not_to be_due
        end
      end
    end

    context "when last run is past the next scheduled time" do
      it "returns true" do
        Timecop.freeze(Time.zone.parse("2026-05-16 10:00:00")) do
          agent = create(:ai_agent)
          create(:ai_agent_execution, :completed, agent:,
                                                  created_at: 2.days.ago)
          expect(agent).to be_due
        end
      end
    end

    context "with invalid cron expression" do
      let(:agent) { create(:ai_agent, cron_expression: "invalid") }

      it "returns false even if never run" do
        expect(agent).not_to be_due
      end

      context "and has a past execution" do
        let!(:execution) do
          create(:ai_agent_execution, :completed, agent:, created_at: 2.days.ago)
        end

        it "still returns false" do
          expect(agent).not_to be_due
        end
      end
    end
  end

  describe "#enqueue!" do
    let(:agent) { create(:ai_agent) }

    it "enqueues an AgentRunJob" do
      expect { agent.enqueue! }
        .to have_enqueued_job(Ai::AgentRunJob)
        .with(agent)
    end
  end
end
