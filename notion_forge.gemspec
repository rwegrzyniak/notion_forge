# frozen_string_literal: true

require_relative "lib/notion_forge/version"

Gem::Specification.new do |spec|
  spec.name = "notion_forge"
  spec.version = NotionForge::VERSION
  spec.authors = ["Johnny"]
  spec.email = ["your.email@example.com"]

  spec.summary = "Infrastructure as Code for Notion"
  spec.description = "A Ruby DSL for creating and managing Notion workspaces with databases, pages, and templates"
  spec.homepage = "https://github.com/johnny/notion_forge"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/johnny/notion_forge"
  spec.metadata["changelog_uri"] = "https://github.com/johnny/notion_forge/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "thor", "~> 1.0"
  spec.add_dependency "yaml", "~> 0.2"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
