#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify setup process with mock data
require_relative "lib/notion_forge"
require_relative "lib/notion_forge/cli"

puts "🧪 Testing NotionForge Setup Process"
puts "=" * 50

# Test data
test_token = "secret_1234567890123456789012345678901234567890123"
test_page_id = "12345678-1234-1234-1234-123456789abc"

# Simulate the setup with test data
puts "\n📋 Testing setup with mock data:"
puts "Token: #{test_token[0..15]}..."
puts "Page ID: #{test_page_id}"

# Create input simulation
input_data = "#{test_token}\n#{test_page_id}\n"

# Run setup with simulated input
IO.popen("bundle exec ./exe/notion_forge setup", "w") do |pipe|
  pipe.write(input_data)
  pipe.close_write
end

puts "\n✅ Setup test completed!"
