# frozen_string_literal: true

module NotionForge
  module Block
    extend self

    def heading(level, text, **opts)
      raise ArgumentError, "Level must be 1-3" unless (1..3).include?(level)

      {
        object: "block",
        type: "heading_#{level}",
        "heading_#{level}": {
          rich_text: [{ text: { content: text } }],
          **opts,
        },
      }
    end

    # Generate h1, h2, h3 methods with define_method
    (1..3).each do |level|
      define_method(:"h#{level}") do |text, **opts|
        heading(level, text, **opts)
      end
    end

    def paragraph(text, **opts)
      {
        object: "block",
        type: "paragraph",
        paragraph: {
          rich_text: [{ text: { content: text } }],
          **opts,
        },
      }
    end

    alias_method :p, :paragraph

    def callout(emoji, text, color: "gray_background")
      {
        object: "block",
        type: "callout",
        callout: {
          icon: { emoji: emoji },
          color: color,
          rich_text: [{ text: { content: text } }],
        },
      }
    end

    def divider
      {
        object: "block",
        type: "divider",
        divider: {},
      }
    end

    alias_method :hr, :divider

    def todo(text, checked: false)
      {
        object: "block",
        type: "to_do",
        to_do: {
          rich_text: [{ text: { content: text } }],
          checked: checked,
        },
      }
    end

    def quote(text)
      {
        object: "block",
        type: "quote",
        quote: {
          rich_text: [{ text: { content: text } }],
        },
      }
    end

    def bullet(text)
      {
        object: "block",
        type: "bulleted_list_item",
        bulleted_list_item: {
          rich_text: [{ text: { content: text } }],
        },
      }
    end

    alias_method :li, :bullet

    def numbered(text)
      {
        object: "block",
        type: "numbered_list_item",
        numbered_list_item: {
          rich_text: [{ text: { content: text } }],
        },
      }
    end

    alias_method :ol, :numbered

    def toggle(title, children = [], &block)
      kids = block ? capture_blocks(&block) : children

      {
        object: "block",
        type: "toggle",
        toggle: {
          rich_text: [{ text: { content: title } }],
          children: kids,
        },
      }
    end

    def code(text, language: "ruby")
      {
        object: "block",
        type: "code",
        code: {
          rich_text: [{ text: { content: text } }],
          language: language,
        },
      }
    end

    # Macro: Create multiple blocks at once
    def list(items, block_type: :bullet)
      items.map { |item| send(block_type, item) }
    end

    private

    def capture_blocks(&block)
      builder = PageBuilder.new(Page.new(title: "", parent_id: ""))
      builder.instance_eval(&block)
      builder.instance_variable_get(:@page).children
    end
  end
end
