# frozen_string_literal: true

module NotionForge
  module Refinements
    refine String do
      def to_state_key
        downcase.gsub(/[^a-z0-9]+/, "_")
      end

      def to_notion_id
        gsub("-", "")
      end

      def to_notion_url
        "https://notion.so/#{to_notion_id}"
      end

      def present?
        !empty?
      end
    end

    refine Hash do
      def symbolize
        transform_keys(&:to_sym)
      end

      def deep_symbolize
        transform_keys(&:to_sym).transform_values { |v| v.is_a?(Hash) ? v.deep_symbolize : v }
      end
    end

    refine Array do
      def to_rich_text
        map { |text| { text: { content: text.to_s } } }
      end

      def parallelize(max_workers: 4, &block)
        return map(&block) unless Ractor.shareable?(self)

        ractors = take(max_workers).map.with_index do |item, _i|
          Ractor.new(item, &block)
        end

        ractors.map(&:take)
      end
    end

    refine NilClass do
      def present?
        false
      end
    end
  end
end
