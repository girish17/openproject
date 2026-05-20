# frozen_string_literal: true

require "billy"
require "spec_helper"

RSpec.describe Ai::Agents::DailySummaryAgent do
  let(:user) { create(:admin) }
  let(:agent) { create(:ai_agent, :daily_summary, user:) }
  subject { described_class.new(agent) }

  describe ".prescribed_prompt" do
    it "returns a prompt string" do
      expect(described_class.prescribed_prompt).to be_a(String)
      expect(described_class.prescribed_prompt.length).to be > 50
    end
  end

  describe "#execute" do
    let(:llm_client) { instance_double(Ai::LlmClient) }
    let(:response_hash) { { "message" => { "content" => "Summary done." } } }

    before do
      allow(Ai::LlmClient).to receive(:new).and_return(llm_client)
      allow(llm_client).to receive(:chat).and_return(response_hash)
    end

    context "with recent work packages" do
      let!(:work_package) do
        create(:work_package,
               subject: "Test WP",
               created_at: 1.hour.ago)
      end

      it "calls the LLM with work package context" do
        subject.execute
        expect(llm_client).to have_received(:chat) do |messages|
          expect(messages.first[:content]).to include(work_package.subject)
        end
      end

      it "returns the LLM response" do
        result = subject.execute
        expect(result).to eq("Summary done.")
      end
    end

    context "without recent work packages" do
      it "handles empty activity gracefully" do
        subject.execute
        expect(llm_client).to have_received(:chat) do |messages|
          expect(messages.first[:content]).to include("No recent activity")
        end
      end
    end

    context "scoped to a project" do
      let(:project) { create(:project) }
      let(:agent) { create(:ai_agent, :daily_summary, user:, project:) }

      before do
        allow(WorkPackage).to receive(:visible).with(user).and_call_original
      end

      it "scopes work packages to the agent's project" do
        subject.execute
        expect(llm_client).to have_received(:chat) do |messages|
          expect(messages.first[:content]).to include("in project #{project.name}")
        end
      end
    end

    context "when LLM returns a plain string" do
      let(:response_hash) { "Plain summary" }

      it "returns the response as-is" do
        result = subject.execute
        expect(result).to eq("Plain summary")
      end
    end
  end
end
