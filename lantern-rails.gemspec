require_relative "lib/lantern/rails/version"

Gem::Specification.new do |spec|
  spec.name        = "lantern-rails"
  spec.version     = Lantern::Rails::VERSION
  spec.authors     = ["Eric Mumbower"]
  spec.summary     = "Postgres monitoring collector for Rails apps — sends health metrics to Lantern."
  spec.homepage              = "https://uselantern.dev"
  spec.metadata["source_code_uri"] = "https://github.com/emum/lantern-rails"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*", "LICENSE", "README.md"]

  spec.add_dependency "rails", ">= 7.0"
end
