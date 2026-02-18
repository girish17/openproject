# Development-only override to allow all enterprise features
Rails.application.config.after_initialize do
  # Override the load_token! method to return a mock token with all features
  module EnterpriseTokenDevOverride
    def load_token!
      @token_object ||= OpenProject::Token.new(
        subscriber: 'Developer',
        mail: 'dev@example.com',
        company: 'DevCo',
        domain: nil,
        validate_domain: false,
        starts_at: Date.yesterday,
        expires_at: 1.year.from_now,
        plan: :basic
      )
    end
  end

  EnterpriseToken.prepend(EnterpriseTokenDevOverride)

  # Clear the RequestStore cache if any
  RequestStore.delete(:current_ee_tokens) if defined?(RequestStore)

  puts 'EnterpriseToken development override loaded - all EE features enabled!'
end
