#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/notion_forge'

# Test DSL with various issues at specific lines
test_dsl_with_line_numbers = <<~DSL
  def forge_workspace
    NotionForge::Workspace.new(title: "Line Number Test") do
      
      # This should cause duplicate property warnings on lines 7 and 8
      projects = database "Projects" do
        title "Name"
        title "Another Name"  # Line 8 - duplicate
        select "Status", options: ["Active", "Done"]
        
        # This should cause status property warning on line 12
        status options: [
          { name: "Todo", color: "gray" }
        ]
        
        # This should cause URL property error on line 16
        url "Website"
        
        # This should cause empty options warning on line 19
        select "Empty", options: []
        
        text "Description"
      end
      
      # This should cause relation error on line 25 (undefined_team reference)
      tasks = database "Tasks" do
        relate "Assignee", undefined_team
      end
      
      # This should cause missing title error on line 30
      database do
        text "Some field"
      end
      
    end
  end
DSL

puts "🧪 Testing Line Number Tracking in Validation"
puts "=" * 60

result = NotionForge::Workspace.validate(test_dsl_with_line_numbers)

puts "Validation Status: #{result[:status]}"
puts "Total Errors: #{result[:summary][:total_errors]}"
puts "Total Warnings: #{result[:summary][:total_warnings]}"

puts "\n❌ Errors with Line Numbers:"
result[:errors].each do |error|
  puts "  Line #{error[:line] || 'N/A'}: #{error[:code]}"
  puts "    #{error[:message]}"
  puts "    Fix: #{error[:fix]}" if error[:fix]
  puts
end

puts "⚠️ Warnings with Line Numbers:"
result[:warnings].each do |warning|
  puts "  Line #{warning[:line] || 'N/A'}: #{warning[:code]}"
  puts "    #{warning[:message]}"
  puts "    Fix: #{warning[:fix]}" if warning[:fix]
  puts
end

# Test editor integration format
puts "=" * 60
puts "📝 Editor Integration Format (VS Code Problems Panel):"
puts "=" * 60

all_issues = result[:errors] + result[:warnings]
all_issues.sort_by { |issue| issue[:line] || 0 }.each do |issue|
  severity = issue[:type] == 'error' ? 'Error' : 'Warning'
  line = issue[:line] || 1
  
  puts "#{severity} (Line #{line}): #{issue[:message]}"
  puts "  Code: #{issue[:code]}"
  puts "  Fix: #{issue[:fix]}" if issue[:fix]
  puts
end

# JSON format for API integration
puts "=" * 60
puts "📄 JSON Response for API Integration:"
puts "=" * 60

api_response = {
  success: result[:status] == 'valid',
  issues: all_issues.map do |issue|
    {
      severity: issue[:type],
      line: issue[:line] || 1,
      column: 1, # Could be enhanced to track columns too
      code: issue[:code],
      message: issue[:message],
      fix: issue[:fix],
      source: 'notionforge-validator'
    }
  end,
  summary: result[:summary]
}

puts JSON.pretty_generate(api_response)

puts "\n✅ Line number tracking test completed!"
puts "🎯 Ready for editor integration with precise error locations!"
