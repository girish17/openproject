module Ai::Tools
  class Base
    def self.tool_spec
      new.tool_spec
    end

    def tool_spec
      raise NotImplementedError
    end

    def execute(params)
      raise NotImplementedError
    end

    protected

    def api
      @api ||= API::V3::Utilities::PathHelper::ApiV3Path
    end
  end
end
