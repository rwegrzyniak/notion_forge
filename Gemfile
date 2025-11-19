# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in notion_forge.gemspec
gemspec

gem "rake", "~> 13.0"

group :development do
  gem "minitest", "~> 5.0"
  gem "minitest-reporters", "~> 1.0"
  gem "rubocop", "~> 1.21"
  gem "rubocop-rake", require: false
  gem "rubocop-minitest", require: false
  gem "yard", "~> 0.9"
  gem "rdoc", "~> 6.0"
end

group :test do
  gem "simplecov", "~> 0.21"
  gem "webmock", "~> 3.0"
  gem "vcr", "~> 6.0"
end
