# frozen_string_literal: true

require "test_helper"

class ParallelExecutorTest < NotionForgeTest
  def test_map_processes_items_sequentially_for_api_safety
    items = [1, 2, 3, 4, 5]
    results = []
    start_time = Time.now
    
    NotionForge::ParallelExecutor.map(items) do |item|
      results << item * 2
      item * 2
    end
    
    elapsed = Time.now - start_time
    
    # Should be sequential with rate limiting
    assert_operator elapsed, :>=, 0.4 # At least 400ms for 4 delays between 5 items
    assert_equal [2, 4, 6, 8, 10], results
  end

  def test_map_respects_rate_limiting_between_requests
    items = [1, 2, 3]
    timestamps = []
    
    NotionForge::ParallelExecutor.map(items) do |item|
      timestamps << Time.now.to_f
      item
    end
    
    # Check that there's proper delay between requests
    delay1 = timestamps[1] - timestamps[0]
    delay2 = timestamps[2] - timestamps[1]
    
    # Should have rate limiting delay (1/3 second = ~0.33s)
    assert_operator delay1, :>=, 0.3
    assert_operator delay2, :>=, 0.3
  end

  def test_map_safe_is_disabled_by_default
    items = [1, 2, 3]
    
    # Should fall back to sequential even with safe method
    result = NotionForge::ParallelExecutor.map_safe(items) { |x| x * 2 }
    
    assert_equal [2, 4, 6], result
  end

  def test_map_uses_mutex_for_thread_safety
    items = (1..10).to_a
    results = []
    
    # Multiple threads trying to use executor
    threads = 3.times.map do
      Thread.new do
        NotionForge::ParallelExecutor.map(items.sample(2)) do |item|
          results << item
          item
        end
      end
    end
    
    threads.each(&:join)
    
    # Should complete without race conditions
    assert_operator results.size, :>=, 6 # At least 2 items per thread
  end

  def test_map_logs_debug_information
    items = [1, 2]
    
    NotionForge.configuration.verbose = true
    
    output = capture_output do
      NotionForge::ParallelExecutor.map(items) { |x| x }
    end
    
    assert_includes output, "Processing 2 items sequentially"
    assert_includes output, "Processing item 1/2"
    assert_includes output, "Processing item 2/2"
  end
end
