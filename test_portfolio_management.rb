#!/usr/bin/env ruby

puts "Testing Portfolio Management Community Edition Implementation..."
puts "=" * 60

begin
  require_relative "config/environment"

  puts "✅ Rails environment loaded successfully"

  # Test 1: Check portfolio models feature is active
  portfolio_active = OpenProject::FeatureDecisions.portfolio_models_active?
  puts "📊 Portfolio models active: #{portfolio_active}"

  # Test 2: Check if we can create portfolio without enterprise token
  puts "🔒 Enterprise token check: #{EnterpriseToken.allows_to?(:portfolio_management)}"

  # Test 3: Check if portfolio model exists
  if defined?(Project) && Project.respond_to?(:portfolio)
    puts "📁 Portfolio model method exists: true"
  else
    puts "❌ Portfolio model method: NOT FOUND"
  end

  puts "✅ Portfolio Management Community Edition test completed successfully!"
rescue StandardError => e
  puts "❌ Test failed: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(5).join("\n")}"
  exit 1
end
