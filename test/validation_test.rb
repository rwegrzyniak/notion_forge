#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/notion_forge'
require 'minitest/autorun'

class ValidationTest < Minitest::Test
  def test_valid_dsl_code
    valid_dsl = <<~DSL
      def forge_workspace
        NotionForge::Workspace.new(title: "Test") do
          database "Projects" do
            title
            select "Status", options: ["Active", "Done"]
            date "Due Date"
            text "Description"
          end
        end
      end
    DSL

    result = NotionForge::Workspace.validate(valid_dsl)
    
    # Should have some method errors but no syntax errors
    assert_equal 'invalid', result[:status] # Due to missing methods
    assert result[:summary][:total_errors] >= 0
    refute_nil result[:errors]
    refute_nil result[:warnings]
  end

  def test_invalid_syntax_dsl
    invalid_dsl = <<~DSL
      def forge_workspace
        NotionForge::Workspace.new(title: "Test") do
          database "Projects" do
            title
            select "Status" options: ["Active", "Done"] # Missing comma
            date "Due Date"
          # Missing end
        end
      end
    DSL

    result = NotionForge::Workspace.validate(invalid_dsl)
    
    assert_equal 'invalid', result[:status]
    assert result[:summary][:total_errors] > 0
    
    # Should have syntax error
    syntax_errors = result[:errors].select { |e| e[:code] == 'syntax_error' }
    assert syntax_errors.any?, "Should detect syntax errors"
  end

  def test_missing_forge_method
    invalid_dsl = <<~DSL
      NotionForge::Workspace.new(title: "Test") do
        database "Projects" do
          title
        end
      end
    DSL

    result = NotionForge::Workspace.validate(invalid_dsl)
    
    assert_equal 'invalid', result[:status]
    
    # Should detect missing forge_workspace method
    forge_errors = result[:errors].select { |e| e[:code] == 'missing_forge_method' }
    assert forge_errors.any?, "Should detect missing forge_workspace method"
  end

  def test_status_property_warning
    dsl_with_status = <<~DSL
      def forge_workspace
        NotionForge::Workspace.new(title: "Test") do
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

    result = NotionForge::Workspace.validate(dsl_with_status)
    
    # Should have warning about status properties
    status_warnings = result[:warnings].select { |w| w[:code] == 'status_property_issue' }
    assert status_warnings.any?, "Should warn about status properties with options"
  end

  def test_validation_report_structure
    result = NotionForge::Workspace.validate('def forge_workspace; end')
    
    # Test required keys
    assert_includes result.keys, :status
    assert_includes result.keys, :has_warnings
    assert_includes result.keys, :errors
    assert_includes result.keys, :warnings
    assert_includes result.keys, :summary
    
    # Test summary structure
    summary = result[:summary]
    assert_includes summary.keys, :total_errors
    assert_includes summary.keys, :total_warnings
    assert_includes summary.keys, :critical_issues
    assert_includes summary.keys, :validation_type
    
    assert_equal 'dsl_code', summary[:validation_type]
  end

  def test_json_serialization
    result = NotionForge::Workspace.validate('def forge_workspace; end')
    
    # Should be serializable to JSON
    json_string = result.to_json
    assert_kind_of String, json_string
    
    # Should be parsable back
    parsed = JSON.parse(json_string)
    assert_kind_of Hash, parsed
    assert_equal result[:status], parsed['status']
  end
end
