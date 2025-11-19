# frozen_string_literal: true

using NotionForge::Refinements

module NotionForge
  class Database < Resource
    attr_accessor :title, :icon, :schema, :relations

    def initialize(title:, parent_id: nil, icon: nil, schema: {}, **opts)
      super(parent_id: parent_id, **opts)
      @title = title
      @icon = icon
      @schema = schema
      @relations = {}
    end

    # Schema DSL
    def prop(name, type, **opts)
      @schema[name] = Property.build(type, **opts)
      self
    end

    alias_method :property, :prop

    def relate(name, target_db, synced: nil)
      @relations[name] = { target: target_db, synced: synced }
      depends_on(target_db)
      self
    end

    alias_method :relation, :relate

    # Find the title property name from the schema
    def title_property_name
      title_prop = schema.find { |name, config| config.dig(:title) }
      title_prop ? title_prop[0] : "Title" # Default to "Title" if not found
    end

    def sync_relations!
      return self if relations.empty?

      props = relations.transform_values do |config|
        target = config[:target]
        target.find_or_create! unless target.persisted?

        {
          relation: {
            database_id: target.id,
            type: "dual_property",
            dual_property: {},
          },
        }
      end

      update!(properties: props)
    end

    # Template factory
    def template(title, icon: nil, props: {}, &block)
      tmpl = Template.new(
        title: title,
        database_id: nil, # Will be set later when database is created
        icon: icon,
        properties: props,
        database: self, # Pass database reference instead
      )
      tmpl.build(&block) if block
      tmpl
    end

    protected

    def name = title
    def resource_path = "/databases/#{id}"
    def create_path = "/databases"

    def to_notion
      {
        parent: { page_id: parent_id },
        title: [{ text: { content: title } }],
        properties: schema,
        icon: icon ? { emoji: icon } : nil,
      }.compact
    end
  end
end
