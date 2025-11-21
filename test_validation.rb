#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for validation functionality
require_relative 'lib/notion_forge'

# Test DSL code with various issues
test_dsl = <<~DSL
  def forge_workspace
    NotionForge::Workspace.new(title: "Test Workspace") do
      # This should work fine
      projects = database "Projects" do
        title
        select "Status", options: ["Active", "Inactive"]
        date "Due Date"
      end
      
      # This should cause a warning (status with options)
      tasks = database "Tasks" do
        title
        status options: [
          { name: "Todo", color: "gray" },
          { name: "Done", color: "green" }
        ]
      end
      
      # This should cause an error if to_notion_url is missing
      contacts = database "Contacts" do
        title
        url "Website"
      end
      
      # This should work
      page "Documentation" do
        # page content
      end
    end
  end
DSL

puts "🧪 Testing NotionForge Validation System"
puts "=" * 50

# Test 1: Validate DSL code
puts "\n1. Testing DSL validation..."
result = NotionForge::Workspace.validate(test_dsl)

puts "Status: #{result[:status]}"
puts "Errors: #{result[:summary][:total_errors]}"
puts "Warnings: #{result[:summary][:total_warnings]}"

if result[:errors].any?
  puts "\n❌ Errors found:"
  result[:errors].each do |error|
    puts "  - #{error[:message]}"
    puts "    Fix: #{error[:fix]}" if error[:fix]
  end
end

if result[:warnings].any?
  puts "\n⚠️ Warnings found:"
  result[:warnings].each do |warning|
    puts "  - #{warning[:message]}"
    puts "    Fix: #{warning[:fix]}" if warning[:fix]
  end
end

# Test 2: Valid DSL
puts "\n" + "=" * 50
puts "2. Testing valid DSL..."

valid_dsl = <<~DSL
  def forge_workspace
    NotionForge::Workspace.new(title: "Valid Workspace") do
      projects = database "Projects" do
        title
        select "Status", options: ["Active", "Inactive"]
        date "Due Date"
        text "Description"
      end
    end
  end
DSL

valid_result = NotionForge::Workspace.validate(valid_dsl)
puts "Status: #{valid_result[:status]}"
puts "Errors: #{valid_result[:summary][:total_errors]}"
puts "Warnings: #{valid_result[:summary][:total_warnings]}"

puts "\n✅ Validation system test completed!"
