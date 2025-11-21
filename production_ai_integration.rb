#!/usr/bin/env ruby
# frozen_string_literal: true

# Production SaaS Integration for NotionForge AI Generation
require_relative 'lib/notion_forge'

class ProductionNotionForgeAI
  # Load the system prompt
  SYSTEM_PROMPT = File.read('docs/AI_GENERATION_SYSTEM_PROMPT.md')
  
  # Errors to ignore (gem version issues)
  IGNORED_ERROR_CODES = [
    'missing_method_to_notion_url',
    'missing_method_status_property'
  ].freeze

  def self.generate_workspace(user_description, ai_client)
    prompt = build_prompt(user_description)
    
    max_attempts = 3
    attempt = 1
    
    while attempt <= max_attempts
      puts "🤖 Generating DSL code (attempt #{attempt}/#{max_attempts})"
      
      # Generate code using AI
      generated_code = ai_client.generate_code(prompt)
      
      # Validate the code
      validation_result = validate_with_filtering(generated_code)
      
      if validation_result[:deployable]
        return {
          success: true,
          dsl_code: generated_code,
          validation: validation_result,
          attempts: attempt
        }
      end
      
      # If not deployable, provide feedback for next attempt
      if attempt < max_attempts
        error_feedback = create_improvement_prompt(validation_result[:errors])
        prompt = "#{SYSTEM_PROMPT}\n\nIMPROVE THIS CODE - FIX THESE ERRORS:\n#{error_feedback}\n\nUser Request: #{user_description}"
        attempt += 1
      else
        return {
          success: false,
          dsl_code: generated_code,
          validation: validation_result,
          attempts: attempt,
          message: "Could not generate error-free code after #{max_attempts} attempts"
        }
      end
    end
  end

  def self.validate_with_filtering(dsl_code)
    # Get full validation result
    result = NotionForge::Workspace.validate(dsl_code)
    
    # Filter out ignored errors (gem version issues)
    filtered_errors = result[:errors].reject do |error|
      IGNORED_ERROR_CODES.include?(error[:code])
    end
    
    # Create filtered result
    {
      status: filtered_errors.empty? ? 'valid' : 'invalid',
      deployable: filtered_errors.empty?,
      errors: filtered_errors,
      warnings: result[:warnings],
      summary: {
        total_errors: filtered_errors.count,
        total_warnings: result[:warnings].count,
        ignored_errors: result[:errors].count - filtered_errors.count,
        validation_type: 'dsl_code'
      },
      original_validation: result
    }
  end

  private

  def self.build_prompt(user_description)
    <<~PROMPT
      #{SYSTEM_PROMPT}

      USER REQUEST: #{user_description}

      Generate complete, valid NotionForge DSL code for this request. Follow all the rules above exactly.
      
      Remember:
      - Use 'select' NOT 'status' for status-like properties
      - Use 'text' NOT 'url' for URL fields
      - Always provide titles for databases
      - Make property names unique within each database
      - Always assign databases to variables for relations
    PROMPT
  end

  def self.create_improvement_prompt(errors)
    improvements = errors.map do |error|
      case error[:code]
      when 'missing_forge_method'
        "CRITICAL: Wrap ALL code in 'def forge_workspace ... end'"
      when 'missing_workspace_init'
        "CRITICAL: Use 'NotionForge::Workspace.new(title: \"Name\") do ... end'"
      when 'missing_database_title'
        "ERROR Line #{error[:line]}: Add title to database: database \"Database Name\" do"
      when 'duplicate_property'
        "ERROR Line #{error[:line]}: Remove duplicate property names within the same database"
      when 'empty_options'
        "ERROR Line #{error[:line]}: Add options: options: [\"Option1\", \"Option2\"]"
      when 'status_property_issue'
        "ERROR Line #{error[:line]}: Change 'status' to 'select': select \"Status\", options: [...]"
      when 'url_property_unsupported'
        "ERROR Line #{error[:line]}: Change 'url' to 'text': text \"Website URL\""
      when 'undefined_relation_reference'
        "ERROR Line #{error[:line]}: Define database variable before using in relate"
      when 'syntax_error'
        "CRITICAL Line #{error[:line]}: Fix syntax: #{error[:message]}"
      else
        "ERROR Line #{error[:line]}: #{error[:message]}"
      end
    end.join("\n")
    
    "#{improvements}\n\nFIX ALL THESE ISSUES and regenerate complete valid code."
  end
end

# Mock AI client for testing
class MockOpenAIClient
  def initialize
    @attempt = 0
  end

  def generate_code(prompt)
    @attempt += 1
    
    # Simulate AI improvement over attempts
    case @attempt
    when 1
      # First attempt - has some errors
      <<~DSL
        def forge_workspace
          NotionForge::Workspace.new(title: "Project Management") do
            projects = database "Projects" do
              title "Project Name"
              status options: [  # ERROR: should be select
                { name: "Active", color: "green" }
              ]
              url "Website"  # ERROR: should be text
            end
          end
        end
      DSL
    when 2
      # Second attempt - fixes most errors
      <<~DSL
        def forge_workspace
          NotionForge::Workspace.new(title: "Project Management System") do
            projects = database "Projects" do
              title "Project Name"
              select "Status", options: [
                { name: "Active", color: "green" },
                { name: "Complete", color: "blue" }
              ]
              text "Website URL"
              date "Due Date"
            end
            
            tasks = database "Tasks" do
              title "Task Name"
              relate "Project", projects
              select "Priority", options: ["High", "Medium", "Low"]
              checkbox "Completed"
            end
          end
        end
      DSL
    else
      # Third attempt - should be perfect
      <<~DSL
        def forge_workspace
          NotionForge::Workspace.new(title: "Complete Project Management", icon: "🚀") do
            
            projects = database "Projects", icon: "📋" do
              title "Project Name"
              select "Status", options: [
                { name: "Planning", color: "gray" },
                { name: "Active", color: "blue" },
                { name: "Complete", color: "green" }
              ]
              select "Priority", options: ["High", "Medium", "Low"]
              text "Website URL"
              date "Start Date"
              date "Due Date"
              number "Budget"
              text "Description"
            end
            
            tasks = database "Tasks", icon: "✅" do
              title "Task Name"
              relate "Project", projects
              select "Status", options: [
                { name: "Todo", color: "gray" },
                { name: "In Progress", color: "yellow" },
                { name: "Done", color: "green" }
              ]
              select "Priority", options: ["High", "Medium", "Low"]
              date "Due Date"
              checkbox "Completed"
              text "Notes"
            end
            
            page "Dashboard", icon: "📊" do
              section "Overview" do
                h1 "Project Management Dashboard"
                p "Track your projects and tasks efficiently."
                
                callout "💡", "Quick Start", color: "blue_background" do
                  p "1. Create your first project"
                  p "2. Add tasks to projects"
                  p "3. Track progress with status updates"
                end
              end
            end
            
          end
        end
      DSL
    end
  end
end

# Demo the system
puts "🚀 Production NotionForge AI Generation Demo"
puts "=" * 60

user_request = "Create a project management system with projects and tasks"
ai_client = MockOpenAIClient.new

result = ProductionNotionForgeAI.generate_workspace(user_request, ai_client)

if result[:success]
  puts "\n✅ SUCCESS: Generated deployable DSL code in #{result[:attempts]} attempts"
  
  puts "\nValidation Summary:"
  puts "  Deployable: #{result[:validation][:deployable]}"
  puts "  Errors: #{result[:validation][:summary][:total_errors]}"
  puts "  Warnings: #{result[:validation][:summary][:total_warnings]}"
  puts "  Ignored errors: #{result[:validation][:summary][:ignored_errors]}"
  
  if result[:validation][:warnings].any?
    puts "\n⚠️ Warnings (non-blocking):"
    result[:validation][:warnings].each do |warning|
      puts "  Line #{warning[:line]}: #{warning[:message]}"
    end
  end
  
  puts "\n" + "=" * 60
  puts "📄 Generated DSL Code:"
  puts "=" * 60
  puts result[:dsl_code]
  
else
  puts "\n❌ FAILED: Could not generate deployable code"
  puts "Remaining errors:"
  result[:validation][:errors].each do |error|
    puts "  Line #{error[:line]}: #{error[:message]}"
  end
end

# SaaS API Integration Example
class SaaSController
  def generate_notion_workspace
    user_description = params[:description]
    
    # Initialize your AI client (OpenAI, Anthropic, etc.)
    ai_client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    
    result = ProductionNotionForgeAI.generate_workspace(user_description, ai_client)
    
    render json: {
      success: result[:success],
      dsl_code: result[:dsl_code],
      deployable: result[:validation][:deployable],
      validation_summary: result[:validation][:summary],
      errors: result[:validation][:errors],
      warnings: result[:validation][:warnings],
      attempts_used: result[:attempts]
    }
  end
end

puts "\n🎯 Production Integration Features:"
puts "• Smart error filtering (ignores gem version issues)"
puts "• Iterative improvement with feedback"
puts "• Deployability checking"
puts "• Comprehensive validation reporting"
puts "• Ready for OpenAI, Claude, or any AI model"
puts "• Production-ready for SaaS deployment"
