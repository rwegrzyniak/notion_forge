#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for page ID extraction
require_relative "lib/notion_forge"
require_relative "lib/notion_forge/cli"

# Create CLI instance to test the method
cli = NotionForge::CLI.new

puts "🧪 Testing Page ID Extraction"
puts "=" * 40

test_cases = [
  "https://www.notion.so/Content-Process-28151ddc6ac080a18c8fed00ba6b6fa3",
  "notion.so/Content-Process-28151ddc6ac080a18c8fed00ba6b6fa3",
  "28151ddc6ac080a18c8fed00ba6b6fa3",
  "28151ddc-6ac0-80a1-8c8f-ed00ba6b6fa3",
  "https://notion.so/workspace/My-Page-28151ddc6ac080a18c8fed00ba6b6fa3?v=123",
  "https://myworkspace.notion.site/Test-Page-28151ddc6ac080a18c8fed00ba6b6fa3",
  "invalid-input",
  "",
  "https://notion.so/short-id-123"
]

test_cases.each do |input|
  result = cli.send(:extract_page_id, input)
  status = result ? "✅" : "❌"
  puts "#{status} Input: #{input.inspect}"
  puts "    Result: #{result || 'nil'}"
  puts
end

puts "🎯 Expected result for your URL:"
your_url = "https://www.notion.so/Content-Process-28151ddc6ac080a18c8fed00ba6b6fa3"
result = cli.send(:extract_page_id, your_url)
puts "URL: #{your_url}"
puts "Extracted ID: #{result}"
puts "✅ Success!" if result == "28151ddc6ac080a18c8fed00ba6b6fa3"
