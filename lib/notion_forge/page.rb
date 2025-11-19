# frozen_string_literal: true

using NotionForge::Refinements

module NotionForge
  class Page < Resource
    attr_accessor :title, :icon, :cover

    def initialize(title:, parent_id: nil, icon: nil, cover: nil, **opts)
      super(parent_id: parent_id, **opts)
      @title = title
      @icon = icon
      @cover = cover
    end

    # Builder DSL
    def add(*blocks)
      @children.concat(blocks)
      self
    end

    alias_method :<<, :add

    def build(&block)
      PageBuilder.new(self).instance_eval(&block) if block
      self
    end

    protected

    def name = title
    def resource_path = "/pages/#{id}"
    def create_path = "/pages"

    def to_notion
      {
        parent: { page_id: parent_id },
        properties: { title: { title: [{ text: { content: title } }] } },
        icon: icon ? { emoji: icon } : nil,
        cover: cover ? { type: "external", external: { url: cover } } : nil,
        children: children.any? ? children : nil,
      }.compact
    end
  end
end
