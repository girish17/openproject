# frozen_string_literal: true

require "billy"
require "spec_helper"

RSpec.describe Ai::AgentSchedulerJob do
  describe "#perform" do
    context "when feature is inactive" do
      before do
        allow(OpenProject::FeatureDecisions).to receive(:ai_agents_active?).and_return(false)
      end

      it "does not enqueue any agents" do
        create(:ai_agent, active: true)
        expect { subject.perform }
          .not_to have_enqueued_job(Ai::AgentRunJob)
      end
    end

    context "when feature is active" do
      before do
        allow(OpenProject::FeatureDecisions).to receive(:ai_agents_active?).and_return(true)
      end

      it "enqueues due agents" do
        agent = create(:ai_agent, active: true)
        allow_any_instance_of(Ai::Agent).to receive(:due?).and_return(true)
        expect { subject.perform }
          .to have_enqueued_job(Ai::AgentRunJob)
          .with(agent)
      end

      it "skips agents that are not due" do
        create(:ai_agent, active: true)
        allow_any_instance_of(Ai::Agent).to receive(:due?).and_return(false)
        expect { subject.perform }
          .not_to have_enqueued_job(Ai::AgentRunJob)
      end

      it "skips inactive agents" do
        create(:ai_agent, :inactive)
        expect { subject.perform }
          .not_to have_enqueued_job(Ai::AgentRunJob)
      end

      it "handles no active agents gracefully" do
        expect { subject.perform }
          .not_to raise_error
      end
    end
  end
end
