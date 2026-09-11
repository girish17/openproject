# frozen_string_literal: true

# Production override to unlock all enterprise features
Rails.application.config.after_initialize do
  # Enterprise features are stubbed per-example in the test suite (with_ee)
  next if Rails.env.test?

  next if EnterpriseToken.table_exists? && EnterpriseToken.active_tokens.any?

  EnterpriseToken.define_singleton_method(:active?) { true }
  EnterpriseToken.define_singleton_method(:allows_to?) { |_feature| true }
  EnterpriseToken.define_singleton_method(:hide_banners?) { true }

  Rails.logger.info "EnterpriseToken production override loaded - all EE features enabled!"
end
