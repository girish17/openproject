module Ai
  class Setting < ApplicationRecord
    self.table_name = "ai_settings"

    validates :ollama_endpoint, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp }
    validates :default_model, presence: true
    validates :max_tokens, numericality: { greater_than: 0, less_than_or_equal_to: 128_000 }
    validates :temperature, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 2.0 }

    def self.instance
      first || create!
    end

    def self.ensure_singleton
      first || create!
    end
  end
end
