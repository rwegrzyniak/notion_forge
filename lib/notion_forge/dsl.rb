# frozen_string_literal: true

module NotionForge
  module DSL
    def forge_workspace(title, **opts, &block)
      NotionForge::Workspace.new(title: title, **opts, &block)
    end

    def query(resources)
      NotionForge::QueryBuilder.new(resources)
    end
  end
end

# Make DSL available at top level
include NotionForge::DSL
