# frozen_string_literal: true

using NotionForge::Refinements

module NotionForge
  class Template < Resource
    attr_accessor :title, :database_id, :icon, :template_props, :database

    def initialize(title:, database_id: nil, icon: nil, properties: {}, database: nil, **opts, &block)
      super(**opts)
      @title = title
      @database_id = database_id
      @database = database
      @icon = icon
      @template_props = properties

      build(&block) if block
    end

    # Get database_id dynamically from the database reference if not set
    def database_id
      @database_id || (@database&.id)
    end

    def build(&)
      PageBuilder.new(self).instance_eval(&) if block_given?
      self
    end

    protected

    def name = title
    def resource_path = "/pages/#{id}"
    def create_path = "/pages"

    def to_notion
      {
        parent: { database_id: database_id },
        properties: build_props,
        icon: icon ? { emoji: icon } : nil,
        children: children.any? ? children : nil,
      }.compact
    end

    def build_props
      # Use the database's title property name instead of hardcoding "Title"
      title_prop_name = database&.title_property_name || "Title"
      base = { title_prop_name => { title: [{ text: { content: title } }] } }

      template_props.each do |key, value|
        base[key] = case value
                    when Hash then value
                    else { select: { name: value.to_s } }
                    end
      end

      base
    end
  end
end
