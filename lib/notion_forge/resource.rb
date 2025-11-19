# frozen_string_literal: true

using NotionForge::Refinements

module NotionForge
  class Resource
    attr_reader :id, :properties, :children
    attr_accessor :parent_id, :metadata

    def initialize(id: nil, properties: {}, children: [], parent_id: nil, **opts)
      @id = id
      @properties = properties
      @children = children
      @parent_id = parent_id
      @metadata = opts[:metadata] || {}
      @dependencies = []
      @lazy_loaded = false
    end

    # Query methods using modern Ruby endless methods
    def exists? = id && client.exists?(resource_path) rescue false
    def persisted? = !id.nil?
    def archived? = properties.dig("archived") == true
    def lazy_loaded? = @lazy_loaded

    # Pattern matching support
    def deconstruct = [id, properties, metadata]

    def deconstruct_keys(keys)
      {
        id: id,
        properties: properties,
        metadata: metadata,
        type: resource_type,
      }
    end

    # CRUD operations with Fiber support
    def fetch!
      raise ResourceNotFoundError, "Cannot fetch without ID" unless id

      # Yield control if running in Fiber context (Ruby 3.0+ compatibility)
      if Fiber.respond_to?(:current) && Fiber.current && 
         Fiber.respond_to?(:main) && Fiber.current != Fiber.main
        Fiber.yield
      end

      @properties = client.get(resource_path)
      @lazy_loaded = true
      self
    end

    def create!
      log "Creating #{resource_type} '#{name}'..."

      # Yield control if running in Fiber context (Ruby 3.0+ compatibility)
      if Fiber.respond_to?(:current) && Fiber.current && 
         Fiber.respond_to?(:main) && Fiber.current != Fiber.main
        Fiber.yield
      end

      response = client.post(create_path, body: to_notion)
      @id = response["id"]
      state.save(state_key, id, metadata: metadata_for_state)
      log_success "Created #{resource_type} '#{name}'"
      self
    end

    def find_or_create!
      if state.exists?(state_key)
        @id = state.get_id(state_key)
        if exists?
          log_success "#{resource_type.capitalize} '#{name}' already exists"
          return self
        end
        log_warn "#{resource_type.capitalize} '#{name}' not found in Notion, recreating..."
      end

      create!
    end

    def update!(**updates)
      raise ResourceNotFoundError, "Cannot update without ID" unless id

      # Yield control if running in Fiber context (Ruby 3.0+ compatibility)
      if Fiber.respond_to?(:current) && Fiber.current && 
         Fiber.respond_to?(:main) && Fiber.current != Fiber.main
        Fiber.yield
      end

      @properties.merge!(updates)
      client.patch(resource_path, body: updates)
      self
    end

    def archive! = update!(archived: true)
    def restore! = update!(archived: false)

    def reload!
      fetch!
      self
    end

    # Lazy loading with memoization
    def load!
      return self if lazy_loaded?

      fetch!
    end

    # Dependency management
    def depends_on(*resources)
      @dependencies.concat(resources)
      self
    end

    def resolve_dependencies!
      # Always sequential for API safety
      @dependencies.each(&:find_or_create!)
      self
    end

    # DSL helpers
    def with(**opts)
      opts.each { |key, value| send(:"#{key}=", value) if respond_to?(:"#{key}=") }
      self
    end

    # Async support
    def async(&block)
      Fiber.new do
        block.call(self)
      end.tap(&:resume)
    end

    protected

    def client = Client.instance
    def state = StateManager.instance

    def resource_type = self.class.name.split("::").last.downcase
    def name = "Unnamed"
    def state_key = "#{resource_type}_#{name.to_state_key}"
    def resource_path = raise NotImplementedError
    def create_path = raise NotImplementedError
    def to_notion = raise NotImplementedError
    def metadata_for_state = { name: name, created_at: Time.now.iso8601, type: resource_type }

    def log(message) = NotionForge.log(:info, message)
    def log_success(message) = NotionForge.log(:success, message)
    def log_warn(message) = NotionForge.log(:warn, message)
    def log_error(message) = NotionForge.log(:error, message)
  end
end
