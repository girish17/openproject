# frozen_string_literal: true

require "billy"
require "spec_helper"

RSpec.describe Ai::Agents::CustomAgent do
  let(:agent) { create(:ai_agent) }
  subject { described_class.new(agent) }

  describe "#execute" do
    let(:llm_client) { instance_double(Ai::LlmClient) }
    let(:response_hash) { { "message" => { "content" => "Task done." } } }

    before do
      allow(Ai::LlmClient).to receive(:new).and_return(llm_client)
      allow(llm_client).to receive(:chat).and_return(response_hash)
    end

    it "calls the LLM with the agent's prompt" do
      subject.execute
      expect(llm_client).to have_received(:chat) do |messages|
        expect(messages.first[:role]).to eq("system")
        expect(messages.first[:content]).to eq(agent.prompt)
      end
    end

    it "returns the LLM response content" do
      result = subject.execute
      expect(result).to eq("Task done.")
    end

    context "when LLM returns a plain string" do
      let(:response_hash) { "Plain string response" }

      it "returns the response as-is" do
        result = subject.execute
        expect(result).to eq("Plain string response")
      end
    end
  end
end
