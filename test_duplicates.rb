#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/notion_forge'

# Test specifically for duplicate properties
duplicate_test_dsl = <<~DSL
  def forge_workspace
    NotionForge::Workspace.new(title: "Duplicate Test") do
      projects = database "Projects" do
        title "Name"
        title "Another Name"  # Line 6 - duplicate title
        select "Status", options: ["Active"]
        text "Description"
        text "Notes" # Line 9 - duplicate text (different names, so OK)
        select "Status", options: ["Done"] # Line 10 - duplicate Status
      end
    end
  end
DSL

puts "🧪 Testing Duplicate Property Detection"
puts "=" * 50

result = NotionForge::Workspace.validate(duplicate_test_dsl)

puts "Warnings found:"
result[:warnings].each do |warning|
  if warning[:code] == 'duplicate_property'
    puts "  Line #{warning[:line]}: #{warning[:message]}"
    puts "    Fix: #{warning[:fix]}"
  end
end

# Let's debug what our validator is finding
puts "\nDSL Lines:"
duplicate_test_dsl.lines.each_with_index do |line, idx|
  puts "#{idx + 1}: #{line.chomp}"
end
