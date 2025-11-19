# frozen_string_literal: true

require_relative "notion_forge/version"
require_relative "notion_forge/configuration"
require_relative "notion_forge/errors"
require_relative "notion_forge/refinements"
require_relative "notion_forge/client"
require_relative "notion_forge/state_manager"
require_relative "notion_forge/parallel_executor"
require_relative "notion_forge/fiber_pool"
require_relative "notion_forge/query_builder"
require_relative "notion_forge/resource"
require_relative "notion_forge/page"
require_relative "notion_forge/database"
require_relative "notion_forge/template"
require_relative "notion_forge/property"
require_relative "notion_forge/block"
require_relative "notion_forge/workspace"
require_relative "notion_forge/builders"
require_relative "notion_forge/resource_collection"
require_relative "notion_forge/drift_checker"
require_relative "notion_forge/dsl"

# NotionForge - Infrastructure as Code for Notion
# Modern Ruby Edition with ALL the sexy features
module NotionForge
  NOTION_VERSION = "2022-06-28"

  class << self
    extend Forwardable

    attr_writer :configuration

    def_delegators :configuration, :token, :parent_page_id, :state_file

    def configuration
      @configuration ||= Configuration.new
    end

    def configure(&)
      yield(configuration)
    end

    def reset!
      @configuration = Configuration.new
    end

    def log(level, message)
      return unless configuration.verbose

      icon = case level
             when :info then "ℹ️"
             when :success then "✅"
             when :warn then "⚠️"
             when :error then "❌"
             when :debug then "🔍"
             else "📝"
             end

      puts "#{icon} #{message}"
    end
  end
end
