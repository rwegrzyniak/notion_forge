# frozen_string_literal: true

require "test_helper"

class NotionForgeTest < Minitest::Test
  def test_has_version_number
    refute_nil NotionForge::VERSION
    assert_match(/\A\d+\.\d+\.\d+\z/, NotionForge::VERSION)
  end

  def test_configuration_returns_configuration_instance
    assert_instance_of NotionForge::Configuration, NotionForge.configuration
  end

  def test_configure_yields_configuration
    yielded_config = nil
    
    NotionForge.configure do |config|
      yielded_config = config
    end
    
    assert_same NotionForge.configuration, yielded_config
  end

  def test_configure_allows_setting_values
    NotionForge.configure do |config|
      config.token = "new_test_token"
      config.verbose = true
    end

    assert_equal "new_test_token", NotionForge.configuration.token
    assert NotionForge.configuration.verbose
  end

  def test_reset_resets_configuration_to_defaults
    # Modify configuration
    NotionForge.configure do |config|
      config.token = "some_token"
      config.verbose = true
    end

    # Reset and verify defaults
    NotionForge.reset!
    
    assert_nil NotionForge.configuration.token
    refute NotionForge.configuration.verbose
    assert_equal ".notionforge.state.yml", NotionForge.configuration.state_file
  end

  def test_log_with_verbose_enabled
    NotionForge.configuration.verbose = true
    
    output = capture_output do
      NotionForge.log(:info, "Test message")
    end
    
    assert_includes output, "ℹ️ Test message"
  end

  def test_log_with_different_levels
    NotionForge.configuration.verbose = true
    
    test_cases = {
      info: "ℹ️",
      success: "✅", 
      warn: "⚠️",
      error: "❌",
      debug: "🔍",
      unknown: "📝",
    }
    
    test_cases.each do |level, emoji|
      output = capture_output do
        NotionForge.log(level, "Test message")
      end
      
      assert_includes output, "#{emoji} Test message"
    end
  end

  def test_log_with_verbose_disabled
    NotionForge.configuration.verbose = false
    
    output = capture_output do
      NotionForge.log(:info, "Test message")
    end
    
    assert_empty output
  end

  def test_forwardable_delegates_work
    NotionForge.configure do |config|
      config.token = "delegate_test_token"
      config.parent_page_id = "delegate_test_page"
      config.state_file = "test.yml"
    end

    assert_equal "delegate_test_token", NotionForge.token
    assert_equal "delegate_test_page", NotionForge.parent_page_id  
    assert_equal "test.yml", NotionForge.state_file
  end
end
