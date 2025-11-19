# frozen_string_literal: true

using NotionForge::Refinements

module NotionForge
  class ResourceCollection
    include Enumerable

    def initialize(resources)
      @resources = resources
    end

    def each(&block)
      return enum_for(:each) unless block

      @resources.each(&block)
    end

    def lazy = @resources.lazy

    # Pattern matching
    def where(**pattern)
      filtered = select do |resource|
        case resource
        in **pattern then true
        else false
        end
      end
      ResourceCollection.new(filtered)
    end

    def databases = select { _1.is_a?(Database) }
    def pages = select { _1.is_a?(Page) }

    # Always sequential for API safety
    def safe_map(&block)
      ParallelExecutor.map(@resources, &block)
    end
  end
end
