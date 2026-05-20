# frozen_string_literal: true

require "billy"
require "spec_helper"

RSpec.describe Ai::AgentRunJob do
  let(:agent) { create(:ai_agent) }

  describe "#perform" do
    context "when feature is inactive" do
      before do
        allow(OpenProject::FeatureDecisions).to receive(:ai_agents_active?).and_return(false)
      end

      it "does nothing" do
        expect { subject.perform(agent) }
          .not_to change(Ai::AgentExecution, :count)
      end
    end

    context "when agent is inactive" do
      let(:agent) { create(:ai_agent, :inactive) }

      before do
        allow(OpenProject::FeatureDecisions).to receive(:ai_agents_active?).and_return(true)
      end

      it "does nothing" do
        expect { subject.perform(agent) }
          .not_to change(Ai::AgentExecution, :count)
      end
    end

    context "when feature is active and agent is active" do
      let(:runner) { instance_double(Ai::Agents::CustomAgent) }

      before do
        allow(OpenProject::FeatureDecisions).to receive(:ai_agents_active?).and_return(true)
        allow(Ai::Agents::Base).to receive(:for).with(agent).and_return(runner)
        allow(runner).to receive(:execute).and_return("Task result")
      end

      it "creates an execution record" do
        expect { subject.perform(agent) }
          .to change(Ai::AgentExecution, :count).by(1)
      end

      it "marks the execution as completed" do
        subject.perform(agent)
        execution = agent.executions.last
        expect(execution).to be_completed
        expect(execution.result).to eq("Task result")
        expect(execution.started_at).to be_present
        expect(execution.completed_at).to be_present
      end

      it "calls the agent runner" do
        subject.perform(agent)
        expect(runner).to have_received(:execute)
      end

      context "when execution raises an error" do
        before do
          allow(runner).to receive(:execute).and_raise(StandardError.new("Something blew up"))
        end

        it "marks the execution as failed" do
          subject.perform(agent)
          execution = agent.executions.last
          expect(execution).to be_failed
          expect(execution.error_message).to include("Something blew up")
        end

        it "does not re-raise the error" do
          expect { subject.perform(agent) }.not_to raise_error
        end
      end
    end
  end
end
