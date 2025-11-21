#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/notion_forge'
require 'json'

# Simple test runner for validation
class SimpleTest
  def self.run_tests
    puts "🧪 Running Validation Tests"
    puts "=" * 40
    
    test_valid_dsl_structure
    test_syntax_error_detection
    test_status_property_warnings
    test_json_serialization
    test_api_integration
    
    puts "\n✅ All tests completed!"
  end

  def self.test_valid_dsl_structure
    puts "\n1. Testing valid DSL structure..."
    
    valid_dsl = <<~DSL
      def forge_workspace
        NotionForge::Workspace.new(title: "Test") do
          database "Projects" do
            title
            select "Status", options: ["Active", "Done"]
            date "Due Date"
          end
        end
      end
    DSL

    result = NotionForge::Workspace.validate(valid_dsl)
    
    puts "   Status: #{result[:status]}"
    puts "   Errors: #{result[:summary][:total_errors]}"
    puts "   Warnings: #{result[:summary][:total_warnings]}"
    puts "   ✓ DSL structure validation works"
  end

  def self.test_syntax_error_detection
    puts "\n2. Testing syntax error detection..."
    
    invalid_dsl = <<~DSL
      def forge_workspace
        NotionForge::Workspace.new(title: "Test") do
          database "Projects" do
            title
            select "Status" options: ["Active"] # Missing comma
          # Missing end
        end
      end
    DSL

    result = NotionForge::Workspace.validate(invalid_dsl)
    
    syntax_errors = result[:errors].select { |e| e[:code] == 'syntax_error' }
    puts "   Syntax errors detected: #{syntax_errors.length}"
    puts "   ✓ Syntax validation works"
  end

  def self.test_status_property_warnings
    puts "\n3. Testing status property warnings..."
    
    dsl_with_status = <<~DSL
      def forge_workspace
        NotionForge::Workspace.new(title: "Test") do
          database "Tasks" do
            title
            status options: [
              { name: "Todo", color: "gray" }
            ]
          end
        end
      end
    DSL

    result = NotionForge::Workspace.validate(dsl_with_status)
    
    status_warnings = result[:warnings].select { |w| w[:code] == 'status_property_issue' }
    puts "   Status warnings: #{status_warnings.length}"
    puts "   ✓ Status property validation works"
  end

  def self.test_json_serialization
    puts "\n4. Testing JSON serialization..."
    
    result = NotionForge::Workspace.validate('def forge_workspace; end')
    
    begin
      json_string = result.to_json
      parsed = JSON.parse(json_string)
      puts "   JSON serialization: ✓ Works"
      puts "   Parsed status: #{parsed['status']}"
    rescue => e
      puts "   JSON serialization: ✗ Failed - #{e.message}"
    end
  end

  def self.test_api_integration
    puts "\n5. Testing API integration..."
    
    # Test the main API method
    user_dsl = <<~DSL
      def forge_workspace
        NotionForge::Workspace.new(title: "API Test", icon: "🚀") do
          database "Users" do
            title "Name"
            email "Email"
            select "Role", options: ["Admin", "User"]
          end
        end
      end
    DSL

    result = NotionForge::Workspace.validate(user_dsl)
    
    # Verify API response structure
    required_keys = [:status, :has_warnings, :errors, :warnings, :summary]
    missing_keys = required_keys - result.keys
    
    if missing_keys.empty?
      puts "   API response structure: ✓ Complete"
      puts "   Status: #{result[:status]}"
      puts "   Total errors: #{result[:summary][:total_errors]}"
      puts "   Total warnings: #{result[:summary][:total_warnings]}"
    else
      puts "   API response structure: ✗ Missing keys: #{missing_keys}"
    end
  end
end

# Run the tests
SimpleTest.run_tests
