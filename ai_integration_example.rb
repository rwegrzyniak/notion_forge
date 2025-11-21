#!/usr/bin/env ruby
# frozen_string_literal: true

# SaaS AI Integration Example
# Shows how to use the AI generation prompt with validation

require_relative 'lib/notion_forge'

class NotionForgeAIAssistant
  # Main prompt for AI code generation
  GENERATION_PROMPT = <<~PROMPT
    You are an expert NotionForge DSL code generator. Generate valid NotionForge DSL code that follows these CRITICAL requirements:

    STRUCTURE REQUIREMENTS:
    1. Always wrap in: def forge_workspace ... end
    2. Always use: NotionForge::Workspace.new(title: "Name") do ... end
    3. Always assign databases to variables: var_name = database "Title" do ... end

    PROPERTY RULES:
    1. Use select instead of status: select "Status", options: [...]
    2. Avoid url properties (use text "URL" instead)
    3. Always provide options for select: options: ["Option1", "Option2"] 
    4. Never use empty options: options: []
    5. Make property names unique within each database

    RELATION RULES:
    1. Define databases before referencing them
    2. Use: relate "Field Name", database_variable
    3. Never reference undefined variables

    SYNTAX RULES:
    1. Always use commas in method calls: select "Name", options: [...]
    2. Always close blocks with 'end'
    3. Match all brackets and parentheses

    Generate DSL code for: {user_request}

    Validate your code against these common errors:
    - Missing forge_workspace wrapper
    - Missing database titles
    - Duplicate property names
    - Empty options arrays
    - Undefined relation references
    - Syntax errors (missing commas, unmatched brackets)
  PROMPT

  def self.generate_and_validate(user_request, ai_model_client)
    # Replace placeholder with actual request
    prompt = GENERATION_PROMPT.gsub('{user_request}', user_request)
    
    max_attempts = 3
    attempt = 1
    
    while attempt <= max_attempts
      puts "🤖 AI Generation Attempt #{attempt}/#{max_attempts}"
      
      # Get code from AI
      generated_code = ai_model_client.generate(prompt)
      
      # Validate the generated code
      result = NotionForge::Workspace.validate(generated_code)
      
      if result[:status] == 'valid'
        puts "✅ Generated valid DSL code!"
        return {
          success: true,
          code: generated_code,
          validation: result
        }
      else
        puts "❌ Generated code has validation errors:"
        result[:errors].each do |error|
          puts "  Line #{error[:line]}: #{error[:code]} - #{error[:message]}"
        end
        
        # Enhance prompt with specific errors for next attempt
        if attempt < max_attempts
          error_feedback = create_error_feedback(result[:errors])
          prompt += "\n\nFIX THESE ERRORS FROM PREVIOUS ATTEMPT:\n#{error_feedback}"
          attempt += 1
        else
          return {
            success: false,
            code: generated_code,
            validation: result,
            message: "Failed to generate valid code after #{max_attempts} attempts"
          }
        end
      end
    end
  end

  private

  def self.create_error_feedback(errors)
    feedback = errors.map do |error|
      case error[:code]
      when 'missing_forge_method'
        "- CRITICAL: Wrap your code in 'def forge_workspace ... end'"
      when 'missing_workspace_init'
        "- CRITICAL: Use 'NotionForge::Workspace.new(title: \"Name\") do ... end'"
      when 'missing_database_title'
        "- ERROR: All databases need titles: database \"Database Name\" do"
      when 'duplicate_property'
        "- ERROR: Remove duplicate property names within databases"
      when 'empty_options'
        "- ERROR: Provide at least one option: options: [\"Option1\", \"Option2\"]"
      when 'status_property_issue'
        "- WARNING: Use 'select' instead of 'status': select \"Status\", options: [...]"
      when 'undefined_relation_reference'
        "- ERROR: Define database variables before using in relations"
      when 'syntax_error'
        "- CRITICAL: Fix syntax error: #{error[:message]}"
      else
        "- Fix: #{error[:message]}"
      end
    end.join("\n")
    
    feedback
  end
end

# Mock AI client for demonstration
class MockAIClient
  def generate(prompt)
    # This would normally call GPT-4, Claude, etc.
    # For demo, return a sample DSL with intentional errors
    <<~DSL
      def forge_workspace
        NotionForge::Workspace.new(title: "Customer Management System") do
          
          customers = database "Customers", icon: "👥" do
            title "Company Name"
            email "Contact Email"
            select "Status", options: [
              { name: "Active", color: "green" },
              { name: "Inactive", color: "gray" }
            ]
            text "Website URL"
            date "Sign Up Date"
            number "Monthly Revenue"
          end
          
          projects = database "Projects", icon: "📋" do
            title "Project Name"
            relate "Customer", customers
            select "Priority", options: ["High", "Medium", "Low"]
            date "Due Date"
            checkbox "Completed"
            text "Description"
          end
          
          page "Dashboard", icon: "📊" do
            section "Overview" do
              h1 "Customer Management Dashboard"
              p "Track your customers and projects efficiently."
              
              callout "💡", "Quick Start", color: "blue_background"
            end
          end
          
        end
      end
    DSL
  end
end

# Example usage in your SaaS
puts "🚀 NotionForge AI Assistant Demo"
puts "=" * 50

user_request = "Create a customer management system with customers and projects databases"

ai_client = MockAIClient.new
result = NotionForgeAIAssistant.generate_and_validate(user_request, ai_client)

if result[:success]
  puts "\n✅ SUCCESS: Generated valid DSL code"
  puts "\nGenerated Code:"
  puts "-" * 30
  puts result[:code]
  
  puts "\nValidation Summary:"
  puts "Errors: #{result[:validation][:summary][:total_errors]}"
  puts "Warnings: #{result[:validation][:summary][:total_warnings]}"
else
  puts "\n❌ FAILED: Could not generate valid code"
  puts "Errors found:"
  result[:validation][:errors].each do |error|
    puts "  - #{error[:message]}"
  end
end

# For your SaaS API integration
class SaaSAPIController
  def generate_workspace
    user_request = params[:description]
    
    # Use your preferred AI service (OpenAI, Anthropic, etc.)
    ai_client = YourAIService.new(api_key: ENV['AI_API_KEY'])
    
    result = NotionForgeAIAssistant.generate_and_validate(user_request, ai_client)
    
    render json: {
      success: result[:success],
      dsl_code: result[:code],
      validation: result[:validation],
      message: result[:message]
    }
  end
end

puts "\n🎯 Integration Summary:"
puts "• AI generates DSL code using structured prompt"
puts "• Automatic validation with retry logic"
puts "• Error feedback improves subsequent attempts"
puts "• Ready for production SaaS integration"
puts "• Supports any AI model (GPT-4, Claude, etc.)"
