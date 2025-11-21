# frozen_string_literal: true

using NotionForge::Refinements

module NotionForge
  class Workspace
    attr_reader :root, :resources

    def initialize(title:, parent_id: nil, icon: "🏛️", cover: nil, &block)
      @root = Page.new(
        title: title,
        parent_id: parent_id || NotionForge.parent_page_id,
        icon: icon,
        cover: cover,
      )
      @resources = []
      @fiber_pool = FiberPool.new(size: 10)

      instance_eval(&block) if block
    end

    # Resource factories
    def database(title, icon: nil, &block)
      db = Database.new(title: title, parent_id: root.id, icon: icon)
      db.instance_variable_set(:@workspace, self) # Pass workspace reference
      DatabaseBuilder.new(db).instance_eval(&block) if block
      @resources << db
      db
    end

    def page(title, icon: nil, cover: nil, &block)
      pg = Page.new(title: title, parent_id: root.id, icon: icon, cover: cover)
      pg.build(&block) if block
      @resources << pg
      pg
    end

    # Add arbitrary resources to the workspace
    def add_resource(resource)
      @resources << resource unless @resources.include?(resource)
      resource
    end

    # Query builder for resources
    def query = QueryBuilder.new(@resources)

    # Pattern matching queries
    def find(**pattern) = query.where(**pattern).to_a
    def find_by_type(klass) = query.of_type(klass).to_a

    # Lazy enumeration
    def each_resource = @resources.lazy

    # Helper methods for resource filtering
    def databases = @resources.select { _1.is_a?(Database) }
    def pages = @resources.select { _1.is_a?(Page) }

    # Pattern matching support
    def deconstruct_keys(keys)
      {
        root: root,
        resources: resources,
        databases: databases,
        pages: pages,
      }
    end

    # Main validation API method for SaaS - returns JSON-serializable hash
    def self.validate(dsl_code)
      validator = Validation::WorkspaceValidator.new(dsl_code)
      validator.validation_report
    end

    def validate_before_deploy
      validator = Validation::WorkspaceValidator.new(self)
      validator.validate
      validator
    end

    def valid_for_deployment?
      validate_before_deploy.valid?
    end

    # Class method for validating DSL code
    def self.validate_dsl(dsl_code)
      validator = Validation::DslValidator.new(dsl_code)
      validator.validate
      validator
    end

    # Safe building strategies
    def forge!(mode: :update)
      puts "🔥 Forging workspace: #{root.title}"
      puts "   Mode: #{mode_emoji(mode)} #{mode.to_s.capitalize}"
      puts "   Strategy: 🛡️ Sequential (API Safe)\n\n"

      case mode
      when :fresh then return if root.exists?
      when :force then reset_workspace!
      end

      root.find_or_create!
      @resources.each { |r| r.parent_id ||= root.id }

      # ALWAYS sequential for API safety
      forge_sequential_with_rate_limiting!
      sync_relations!
      print_summary
    end

    alias_method :build!, :forge!

    # Async forging with Fibers (safer than Ractors for API)
    def forge_async!(mode: :update, &block)
      Fiber.new do
        forge!(mode: mode)
        block.call(self) if block
      end.tap(&:resume)
    end

    private

    def forge_sequential_with_rate_limiting!
      NotionForge.log(:info, "🛡️ Forging resources sequentially with rate limiting...")
      
      # Group resources by dependency level
      dependency_groups = build_dependency_groups
      
      dependency_groups.each_with_index do |group, level|
        NotionForge.log(:info, "📋 Processing dependency level #{level + 1} (#{group.size} resources)")
        
        group.each_with_index do |resource, index|
          # Rate limiting between requests
          sleep(0.5) if index > 0 # 2 requests per second max
          
          begin
            resource.resolve_dependencies!
            resource.find_or_create!
            NotionForge.log(:success, "✅ #{resource.class.name}: #{resource.send(:name)}")
          rescue => e
            NotionForge.log(:error, "❌ Failed to create #{resource.class.name}: #{e.message}")
            raise
          end
        end
        
        # Pause between dependency levels
        sleep(1) if level < dependency_groups.size - 1
      end
    end

    def build_dependency_groups
      # Topological sort by dependencies
      groups = []
      remaining = @resources.dup
      processed = Set.new

      while remaining.any?
        # Find resources with no unprocessed dependencies
        ready = remaining.select do |resource|
          deps = resource.instance_variable_get(:@dependencies) || []
          deps.all? { |dep| processed.include?(dep) }
        end

        if ready.empty?
          # Circular dependency or other issue - process remaining anyway
          ready = remaining
        end

        groups << ready
        remaining -= ready
        processed.merge(ready)
      end

      groups
    end

    def sync_relations!
      databases.each do |db|
        sleep(0.3) # Rate limiting for relation sync
        db.sync_relations!
      end
    end

    def reset_workspace!
      root.archive! if root.exists?
      StateManager.instance.clear!
    end

    def mode_emoji(mode) = case mode
                           when :fresh then "🆕"
                           when :update then "🔄"
                           when :force then "⚠️"
                           end

    def print_summary
      puts "\n" + "=" * 60
      puts "🎉 WORKSPACE FORGED SAFELY!"
      puts "=" * 60
      puts "🔗 URL: #{root.id.to_notion_url}"
      puts "\n📊 Resources created:"
      puts "   • Databases: #{databases.count}"
      puts "   • Pages: #{pages.count}"
      puts "   • Total: #{@resources.count}"

      # Pattern matching stats
      case [@resources.count, databases.count, pages.count]
      in [0, _, _]
        puts "\n⚠️  No resources created!"
      in [total, dbs, pages] if total > 10
        puts "\n🚀 Large workspace detected (#{total} resources)"
        puts "⏱️  Rate limited for API safety"
      in [_, dbs, _] if dbs > 5
        puts "\n📚 Database-heavy workspace (#{dbs} databases)"
        puts "🔗 Relations synced safely"
      else
        puts "\n✨ Workspace looks great!"
      end

      puts "\n🛡️ All operations completed with API safety measures"
      puts "=" * 60
    end
  end
end
