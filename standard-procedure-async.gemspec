# frozen_string_literal: true

require_relative "lib/standard/procedure/async/version"

Gem::Specification.new do |spec|
  spec.name = "standard-procedure-async"
  spec.version = Standard::Procedure::Async::VERSION
  spec.authors = ["Rahoul Baruah"]
  spec.email = ["rahoulb@standardprocedure.app"]

  spec.summary = "A simple wrapper around Concurrent::Future to make concurrent-ruby Rails-friendly."
  spec.description = "Provides a wrapper around concurrent-ruby's Concurrent::Future to automatically wrap it in a Rails-friendly executor."
  spec.homepage = "https://github.com/standard-procedure/async"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["allowed_push_host"] = "https://example.com"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/standard-procedure/async"
  spec.metadata["changelog_uri"] = "https://github.com/standard-procedure/async/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "concurrent-ruby", ">= 1.0"
  spec.add_development_dependency "activesupport"
  spec.add_development_dependency "railties"
  spec.add_development_dependency "concurrent_rails"
end
