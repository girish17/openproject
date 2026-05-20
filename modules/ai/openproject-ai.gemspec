Gem::Specification.new do |s|
  s.name        = "openproject-ai"
  s.version     = "1.0.0"
  s.authors     = "Yojana"
  s.email       = "info@yojana.dev"
  s.summary     = "Yojana AI"
  s.description = "AI-native features for Yojana including chat assistant, inline AI, and agents powered by Ollama."
  s.license     = "GPLv3"

  s.files = Dir["{app,config,db,lib}/**/*"]
  s.metadata["rubygems_mfa_required"] = "true"
end
