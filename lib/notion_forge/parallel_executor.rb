# frozen_string_literal: true

module NotionForge
  class ParallelExecutor
    # Rate limiting and safety for Notion API
    NOTION_RATE_LIMIT = 3 # requests per second
    MUTEX = Mutex.new
    
    class << self
      def map(items, max_workers: 4, &block)
        # NEVER use parallel for API calls - too dangerous!
        # Notion API has:
        # - Rate limiting (429 Too Many Requests)
        # - State conflicts (duplicate resources)
        # - Dependency hell (relations need order)
        # - No immediate consistency guarantee
        
        NotionForge.log(:debug, "Processing #{items.size} items sequentially (API safety)")
        
        items.map.with_index do |item, index|
          # Respect rate limiting
          sleep_for_rate_limit if index > 0
          
          MUTEX.synchronize do
            NotionForge.log(:debug, "Processing item #{index + 1}/#{items.size}")
            block.call(item)
          end
        end
      end
      
      # Safe parallel execution for non-API operations only
      def map_safe(items, max_workers: 4, &block)
        return items.map(&block) unless parallel_safe?
        
        begin
          # Only for pure computation, file operations, etc.
          # NEVER for API calls!
          ractors = items.first(max_workers).map do |item|
            Ractor.new(item, &block)
          end
          
          ractors.map(&:take)
        rescue => e
          NotionForge.log(:warn, "Ractor failed, falling back to sequential: #{e.message}")
          items.map(&block)
        end
      end
      
      private
      
      def sleep_for_rate_limit
        sleep(1.0 / NOTION_RATE_LIMIT)
      end
      
      def parallel_safe?
        # Only enable for non-API operations
        # Could be used for file processing, validation, etc.
        false # Disabled by default for safety
      end
    end
  end
end
