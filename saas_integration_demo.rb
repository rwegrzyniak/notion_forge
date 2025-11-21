#!/usr/bin/env ruby
# frozen_string_literal: true

# Complete SaaS Integration Example for NotionForge Validation
require_relative 'lib/notion_forge'
require 'json'

class NotionWorkspaceSaaS
  # Main API endpoint for validating user DSL code
  def self.validate_workspace_dsl(user_dsl_code, options = {})
    begin
      # Use the NotionForge validation system
      validation_result = NotionForge::Workspace.validate(user_dsl_code)
      
      # Create standardized API response
      {
        success: validation_result[:status] == 'valid',
        deployable: validation_result[:status] == 'valid' && validation_result[:summary][:total_errors] == 0,
        validation: validation_result,
        metadata: {
          validated_at: Time.now.iso8601,
          validation_version: NotionForge::VERSION,
          strict_mode: options[:strict] || false
        }
      }
    rescue => e
      # Handle unexpected errors gracefully
      {
        success: false,
        deployable: false,
        error: {
          type: 'validation_system_error',
          message: e.message,
          backtrace: options[:debug] ? e.backtrace : nil
        },
        metadata: {
          validated_at: Time.now.iso8601,
          validation_version: NotionForge::VERSION
        }
      }
    end
  end

  # Example: Web API controller method
  def self.api_validate_endpoint(request_body)
    dsl_code = request_body['dsl_code']
    options = request_body['options'] || {}
    
    if dsl_code.nil? || dsl_code.empty?
      return {
        success: false,
        error: {
          type: 'missing_dsl_code',
          message: 'DSL code is required for validation'
        }
      }
    end
    
    validate_workspace_dsl(dsl_code, options)
  end

  # Example: Background job for validation
  def self.validate_async(user_id, dsl_code, callback_url = nil)
    result = validate_workspace_dsl(dsl_code)
    
    # Store result in database
    # ValidationResult.create!(
    #   user_id: user_id,
    #   dsl_code: dsl_code,
    #   result: result,
    #   created_at: Time.now
    # )
    
    # Send webhook if callback URL provided
    if callback_url && result[:success]
      # HTTP.post(callback_url, json: result)
    end
    
    result
  end
end

# Demo: Different types of DSL code and their validation results

demo_cases = [
  {
    name: "✅ Valid DSL",
    dsl: <<~DSL
      def forge_workspace
        NotionForge::Workspace.new(title: "Customer Management", icon: "🏢") do
          customers = database "Customers" do
            title "Company Name"
            email "Contact Email"
            select "Status", options: ["Active", "Inactive", "Prospect"]
            date "Sign Up Date"
            number "Monthly Revenue"
            text "Notes"
          end
          
          projects = database "Projects" do
            title
            select "Priority", options: ["High", "Medium", "Low"]
            date "Due Date"
            checkbox "Completed"
            relate "Customer", customers
          end
          
          page "Dashboard", icon: "📊" do
            # Dashboard content
          end
        end
      end
    DSL
  },
  
  {
    name: "❌ Syntax Error",
    dsl: <<~DSL
      def forge_workspace
        NotionForge::Workspace.new(title: "Broken Workspace") do
          database "Projects" do
            title
            select "Status" options: ["Active"] # Missing comma
          # Missing end
        end
      end
    DSL
  },
  
  {
    name: "⚠️ Status Property Warning",
    dsl: <<~DSL
      def forge_workspace
        NotionForge::Workspace.new(title: "Warning Example") do
          database "Tasks" do
            title
            status options: [
              { name: "Todo", color: "gray" },
              { name: "Done", color: "green" }
            ]
          end
        end
      end
    DSL
  },
  
  {
    name: "❌ Missing Structure",
    dsl: <<~DSL
      # Missing forge_workspace method
      NotionForge::Workspace.new(title: "No Method") do
        database "Test" do
          title
        end
      end
    DSL
  }
]

puts "🚀 NotionForge SaaS Validation Demo"
puts "=" * 50

demo_cases.each_with_index do |demo_case, index|
  puts "\n#{index + 1}. #{demo_case[:name]}"
  puts "-" * 40
  
  result = NotionWorkspaceSaaS.validate_workspace_dsl(demo_case[:dsl])
  
  puts "Success: #{result[:success]}"
  puts "Deployable: #{result[:deployable]}"
  
  if result[:validation]
    puts "Errors: #{result[:validation][:summary][:total_errors]}"
    puts "Warnings: #{result[:validation][:summary][:total_warnings]}"
  end
  
  if result[:error]
    puts "System Error: #{result[:error][:message]}"
  end
end

# Example API response JSON
puts "\n" + "=" * 50
puts "📄 Example JSON API Response:"
puts "=" * 50

api_request = {
  'dsl_code' => demo_cases.first[:dsl],
  'options' => { 'strict' => false }
}

api_response = NotionWorkspaceSaaS.api_validate_endpoint(api_request)
puts JSON.pretty_generate(api_response)

puts "\n🎯 Integration Summary:"
puts "• Main method: NotionWorkspaceSaaS.validate_workspace_dsl(dsl_code)"
puts "• Returns structured hash with success/error status"
puts "• Includes detailed validation results for user feedback"
puts "• JSON serializable for API responses"
puts "• Handles errors gracefully"
puts "• Ready for production SaaS integration!"
