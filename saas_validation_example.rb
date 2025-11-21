#!/usr/bin/env ruby
# frozen_string_literal: true

# Example usage for SaaS integration
require_relative 'lib/notion_forge'

# Example: How your SaaS would use the validation API
class NotionForgeSaaS
  def self.validate_user_dsl(user_dsl_code)
    # This is the main API method your SaaS would call
    result = NotionForge::Workspace.validate(user_dsl_code)
    
    # Return structured response for your API
    {
      success: result[:status] == 'valid',
      validation: result,
      deployable: result[:status] == 'valid' && result[:summary][:total_errors] == 0
    }
  end
end

# Example DSL from user input
user_dsl = <<~DSL
  def forge_workspace
    NotionForge::Workspace.new(title: "My SaaS Workspace", icon: "🚀") do
      
      # Customer database
      customers = database "Customers", icon: "👥" do
        title "Company Name"
        email "Contact Email"
        select "Status", options: [
          { name: "Active", color: "green" },
          { name: "Inactive", color: "gray" }
        ]
        date "Sign Up Date"
        number "Monthly Revenue"
        text "Notes"
      end
      
      # Project tracking
      projects = database "Projects", icon: "📋" do
        title
        select "Priority", options: ["High", "Medium", "Low"]
        date "Due Date"
        checkbox "Completed"
        relate "Customer", customers
      end
      
      # Documentation page
      page "Getting Started", icon: "📚" do
        # Page content would go here
      end
      
    end
  end
DSL

puts "🚀 SaaS Validation Example"
puts "=" * 40

result = NotionForgeSaaS.validate_user_dsl(user_dsl)

puts "Validation Result:"
puts "  Success: #{result[:success]}"
puts "  Deployable: #{result[:deployable]}"
puts "  Errors: #{result[:validation][:summary][:total_errors]}"
puts "  Warnings: #{result[:validation][:summary][:total_warnings]}"

if result[:validation][:errors].any?
  puts "\n❌ Issues found:"
  result[:validation][:errors].each do |error|
    puts "  - #{error[:code]}: #{error[:message]}"
  end
end

if result[:validation][:warnings].any?
  puts "\n⚠️ Warnings:"
  result[:validation][:warnings].each do |warning|
    puts "  - #{warning[:code]}: #{warning[:message]}"
  end
end

# Example JSON API response
puts "\n" + "=" * 40
puts "JSON API Response:"
puts result.to_json
