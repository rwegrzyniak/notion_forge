# frozen_string_literal: true

require "test_helper"

class ClientTest < NotionForgeTest
  def setup
    super
    @client = NotionForge::Client.instance
  end

  def test_get_request_with_rate_limiting
    stub_notion_request(:get, "/pages/test123", response_body: { "id" => "test123" })
    
    start_time = Time.now
    
    # Make two requests to test rate limiting
    result1 = @client.get("/pages/test123")
    result2 = @client.get("/pages/test123")
    
    elapsed = Time.now - start_time
    
    assert_equal "test123", result1["id"]
    assert_equal "test123", result2["id"]
    
    # Should have rate limiting delay between requests
    assert_operator elapsed, :>=, 0.5
  end

  def test_post_request_with_body
    expected_body = { parent: { page_id: "parent123" }, properties: {} }
    
    stub_notion_request(:post, "/pages", response_body: { "id" => "new_page" })
    
    result = @client.post("/pages", body: expected_body)
    
    assert_equal "new_page", result["id"]
  end

  def test_patch_request_with_body
    update_body = { archived: true }
    
    stub_notion_request(:patch, "/pages/test123", response_body: { "id" => "test123", "archived" => true })
    
    result = @client.patch("/pages/test123", body: update_body)
    
    assert_equal "test123", result["id"]
    assert result["archived"]
  end

  def test_exists_returns_true_for_active_resource
    stub_notion_request(:get, "/pages/test123", response_body: { "id" => "test123", "archived" => false })
    
    assert @client.exists?("/pages/test123")
  end

  def test_exists_returns_false_for_archived_resource
    stub_notion_request(:get, "/pages/test123", response_body: { "id" => "test123", "archived" => true })
    
    refute @client.exists?("/pages/test123")
  end

  def test_exists_returns_false_on_error
    stub_request(:get, "https://api.notion.com/v1/pages/nonexistent")
      .to_return(status: 404, body: "Not Found")
    
    refute @client.exists?("/pages/nonexistent")
  end

  def test_rate_limiting_with_429_response
    # First request returns 429, second succeeds
    stub_request(:get, "https://api.notion.com/v1/pages/test123")
      .to_return(status: 429, body: "Rate Limited")
      .then.to_return(status: 200, body: { "id" => "test123" }.to_json)
    
    start_time = Time.now
    
    result = @client.get("/pages/test123")
    
    elapsed = Time.now - start_time
    
    assert_equal "test123", result["id"]
    # Should have exponential backoff delay
    assert_operator elapsed, :>=, 1.0 # At least 1 second for first retry
  end

  def test_multiple_429_retries_then_failure
    # All requests return 429
    stub_request(:get, "https://api.notion.com/v1/pages/test123")
      .to_return(status: 429, body: "Rate Limited").times(3)
    
    error = assert_raises(NotionForge::APIError) do
      @client.get("/pages/test123")
    end
    
    assert_includes error.message, "Rate limited"
  end

  def test_401_unauthorized_error
    stub_request(:get, "https://api.notion.com/v1/pages/test123")
      .to_return(status: 401, body: "Unauthorized")
    
    error = assert_raises(NotionForge::APIError) do
      @client.get("/pages/test123")
    end
    
    assert_includes error.message, "Invalid token"
  end

  def test_403_forbidden_error
    stub_request(:get, "https://api.notion.com/v1/pages/test123")
      .to_return(status: 403, body: "Forbidden")
    
    error = assert_raises(NotionForge::APIError) do
      @client.get("/pages/test123")
    end
    
    assert_includes error.message, "check permissions"
  end

  def test_404_not_found_error
    stub_request(:get, "https://api.notion.com/v1/pages/test123")
      .to_return(status: 404, body: "Not Found")
    
    error = assert_raises(NotionForge::APIError) do
      @client.get("/pages/test123")
    end
    
    assert_includes error.message, "Resource not found"
  end

  def test_request_headers_include_required_fields
    stub_request(:get, "https://api.notion.com/v1/pages/test123")
      .with(headers: {
        "Authorization" => "Bearer test_token_123",
        "Notion-Version" => NotionForge::NOTION_VERSION,
        "Content-Type" => "application/json",
        "User-Agent" => "NotionForge/#{NotionForge::VERSION}",
      })
      .to_return(status: 200, body: { "id" => "test123" }.to_json)
    
    @client.get("/pages/test123")
    
    # Assertion is in the stub - if headers don't match, WebMock will fail
  end

  def test_singleton_pattern
    client1 = NotionForge::Client.instance
    client2 = NotionForge::Client.instance
    
    assert_same client1, client2
  end

  def test_class_methods_delegate_to_instance
    stub_notion_request(:get, "/pages/test123", response_body: { "id" => "test123" })
    
    # Should work through class methods
    result = NotionForge::Client.get("/pages/test123")
    
    assert_equal "test123", result["id"]
  end
end
