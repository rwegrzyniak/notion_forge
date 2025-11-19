# frozen_string_literal: true

using NotionForge::Refinements

module NotionForge
  class QueryBuilder
    include Enumerable

    def initialize(collection)
      @collection = collection
      @filters = []
    end

    def where(**pattern)
      @filters << ->(item) do
        case item
        in **pattern then true
        else false
        end
      end
      self
    end

    def of_type(klass)
      @filters << ->(item) { item.is_a?(klass) }
      self
    end

    def filter(&block)
      @filters << block
      self
    end

    def map(&block)
      each.lazy.map(&block).force
    end

    def lazy
      each.lazy
    end

    def each(&block)
      return enum_for(:each) unless block

      @collection.each do |item|
        yield item if @filters.all? { _1.call(item) }
      end
    end

    # Pattern matching support
    def deconstruct = to_a
    def deconstruct_keys(keys) = to_a.first&.deconstruct_keys(keys)
  end
end
