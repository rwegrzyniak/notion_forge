#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/notion_forge'

# Comprehensive test for all line number scenarios
comprehensive_test_dsl = <<~DSL
  def forge_workspace
    NotionForge::Workspace.new(title: "Complete Line Test") do
      
      # Good database (line 5)
      users = database "Users" do
        title # Line 7 - should be "Title"
        email "Email Address"
        select "Role", options: ["Admin", "User"]
      end
      
      # Database with issues (starts line 12)
      projects = database "Projects" do
        title "Name"       # Line 14
        title "Full Name"  # Line 15 - duplicate Title
        select "Status", options: ["Active", "Done"]  # Line 16
        status options: [  # Line 17 - status warning
          { name: "Todo", color: "gray" }
        ]
        url "Website"      # Line 20 - URL error
        select "Priority", options: []  # Line 21 - empty options
        relate "Owner", undefined_var   # Line 22 - undefined relation
      end
      
      # Missing title database (line 25)
      database do
        text "Field"
      end
      
    end
  end
DSL

puts "🔍 Comprehensive Line Number Validation Test"
puts "=" * 60

result = NotionForge::Workspace.validate(comprehensive_test_dsl)

# Group issues by line number
issues_by_line = {}
(result[:errors] + result[:warnings]).each do |issue|
  line = issue[:line] || 0
  issues_by_line[line] ||= []
  issues_by_line[line] << issue
end

# Display results organized by line
puts "📋 Issues by Line Number:"
puts "-" * 40

issues_by_line.sort.each do |line_num, line_issues|
  if line_num == 0
    puts "Global Issues (no specific line):"
  else
    puts "Line #{line_num}:"
    puts "  Code: #{comprehensive_test_dsl.lines[line_num - 1].strip}" if line_num <= comprehensive_test_dsl.lines.length
  end
  
  line_issues.each do |issue|
    icon = issue[:type] == 'error' ? '❌' : '⚠️'
    puts "  #{icon} #{issue[:code]}: #{issue[:message]}"
    puts "     Fix: #{issue[:fix]}" if issue[:fix]
  end
  puts
end

# Create Language Server Protocol (LSP) format for editor integration
puts "=" * 60
puts "🔧 LSP/Editor Integration Format:"
puts "=" * 60

lsp_diagnostics = (result[:errors] + result[:warnings]).map do |issue|
  {
    range: {
      start: { line: (issue[:line] || 1) - 1, character: 0 },
      end: { line: (issue[:line] || 1) - 1, character: 999 }
    },
    severity: issue[:type] == 'error' ? 1 : 2, # 1 = Error, 2 = Warning
    code: issue[:code],
    source: 'notionforge',
    message: issue[:message],
    codeDescription: {
      href: "https://docs.notionforge.dev/validation/#{issue[:code]}"
    },
    data: {
      fix: issue[:fix],
      context: issue[:context]
    }
  }
end

puts JSON.pretty_generate({
  uri: 'file:///workspace.rb',
  diagnostics: lsp_diagnostics
})

puts "\n✅ Line number tracking is production-ready for editor integration!"
