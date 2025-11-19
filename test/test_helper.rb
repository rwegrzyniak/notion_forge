# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "notion_forge"
require "minitest/autorun"
require "minitest/reporters"
require "webmock/minitest"
require "vcr"

# Use parallel execution for faster tests
# Minitest.parallel_executor = Minitest::Parallel::Executor.new(4)

# Configure beautiful test output
Minitest::Reporters.use! [
  Minitest::Reporters::ProgressReporter.new(color: true),
]

# Configure VCR for API testing
VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data("<NOTION_TOKEN>") { ENV.fetch("NOTION_TOKEN", "fake_token") }
end

# Base test class with common setup
class NotionForgeTest < Minitest::Test
  # Enable parallel execution for this test class
  parallelize_me!

  def setup
    # Reset configuration before each test
    NotionForge.reset!
    
    # Configure test environment
    NotionForge.configure do |config|
      config.token = "test_token_123"
      config.parent_page_id = "test_page_123"
      config.verbose = false
    end
  end

  def teardown
    # Clean up after each test
    NotionForge.reset!
  end

  private

  # Helper to capture stdout
  def capture_output
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end

  # Helper to stub HTTP requests
  def stub_notion_request(method, path, response_body: {}, status: 200)
    stub_request(method, "https://api.notion.com/v1#{path}")
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" },
      )
  end
end
