# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < NotionForgeTest
  def setup
    super
    @config = NotionForge::Configuration.new
  end

  def test_default_values
    assert_equal ".notionforge.state.yml", @config.state_file
    refute @config.verbose
    assert_equal 4, @config.max_workers
  end

  def test_valid_returns_true_when_required_fields_present
    @config.token = "test_token"
    @config.parent_page_id = "test_page_id"
    
    assert @config.valid?
  end

  def test_valid_returns_false_when_token_missing
    @config.parent_page_id = "test_page_id"
    
    refute @config.valid?
  end

  def test_valid_returns_false_when_parent_page_id_missing
    @config.token = "test_token"
    
    refute @config.valid?
  end

  def test_validate_raises_error_when_token_missing
    @config.parent_page_id = "test_page_id"
    
    error = assert_raises(NotionForge::ConfigurationError) do
      @config.validate!
    end
    
    assert_equal "Missing token", error.message
  end

  def test_validate_raises_error_when_parent_page_id_missing
    @config.token = "test_token"
    
    error = assert_raises(NotionForge::ConfigurationError) do
      @config.validate!
    end
    
    assert_equal "Missing parent_page_id", error.message
  end

  def test_validate_succeeds_when_all_required_fields_present
    @config.token = "test_token"
    @config.parent_page_id = "test_page_id"
    
    # Should not raise
    @config.validate!
  end

  def test_merge_sets_provided_options
    result = @config.merge(
      verbose: true,
      max_workers: 8,
      nonexistent_option: "ignored",
    )
    
    assert_same @config, result
    assert @config.verbose
    assert_equal 8, @config.max_workers
  end

  def test_merge_ignores_unknown_options
    # Should not raise even with unknown option
    @config.merge(unknown_option: "value")
    
    # Should not have added unknown method
    refute_respond_to @config, :unknown_option
  end
end
