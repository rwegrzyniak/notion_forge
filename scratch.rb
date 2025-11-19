#!/usr/bin/env ruby
# frozen_string_literal: true
# typed: strict

require 'net/http'
require 'json'
require 'yaml'
require 'optparse'
require 'singleton'
require 'forwardable'
require 'fiber'

# ============================================
# NOTIONFORGE - Infrastructure as Code for Notion
# Modern Ruby Edition with ALL the sexy features
# ============================================

module NotionForge
  VERSION = '0.1.0'
  NOTION_VERSION = '2022-06-28'
  
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ResourceNotFoundError < Error; end
  class APIError < Error; end
  class ValidationError < Error; end
  
  class << self
    extend Forwardable
    
    attr_writer :configuration
    
    def_delegators :configuration, :token, :parent_page_id, :state_file, :parallel
    
    def configuration = @configuration ||= Configuration.new
    
    def configure(&) = yield(configuration)
    
    def reset! = @configuration = Configuration.new
    
    # sig { params(level: Symbol, message: String).void }
    def log(level, message)
      return unless configuration.verbose
      
      icon = case level
             when :info then 'ℹ️'
             when :success then '✅'
             when :warn then '⚠️'
             when :error then '❌'
             when :debug then '🔍'
             else '📝'
             end
      
      puts "#{icon} #{message}"
    end
  end
  
  class Configuration
    attr_accessor :token, :parent_page_id, :state_file, :verbose, :parallel, :max_workers
    
    def initialize
      @state_file = '.notionforge.state.yml'
      @verbose = false
      @parallel = false
      @max_workers = 4
    end
    
    # sig { returns(T::Boolean) }
    def valid? = token && parent_page_id
    
    # sig { void }
    def validate!
      raise ConfigurationError, 'Missing token' unless token
      raise ConfigurationError, 'Missing parent_page_id' unless parent_page_id
    end
    
    # sig { params(opts: T::Hash[Symbol, T.untyped]).returns(Configuration) }
    def merge(**opts)
      opts.each { |k, v| send(:"#{k}=", v) if respond_to?(:"#{k}=") }
      self
    end
  end
  
  # ============================================
  # REFINEMENTS - Syntactic Sugar
  # ============================================
  
  module Refinements
    refine String do
      def to_state_key = downcase.gsub(/[^a-z0-9]+/, '_')
      def to_notion_id = gsub('-', '')
      def to_notion_url = "https://notion.so/#{to_notion_id}"
      def present? = !empty?
    end
    
    refine Hash do
      def symbolize = transform_keys(&:to_sym)
      def deep_symbolize = transform_keys(&:to_sym).transform_values { |v| v.is_a?(Hash) ? v.deep_symbolize : v }
    end
    
    refine Array do
      def to_rich_text = map { |text| { text: { content: text.to_s } } }
      def parallelize(max_workers: 4, &block)
        return map(&block) unless Ractor.shareable?(self)
        
        ractors = take(max_workers).map.with_index do |item, i|
          Ractor.new(item, &block)
        end
        
        ractors.map(&:take)
      end
    end
    
    refine NilClass do
      def present? = false
    end
  end
  
  using Refinements
  
  # ============================================
  # ASYNC FIBER POOL
  # ============================================
  
  class FiberPool
    # sig { params(size: Integer).void }
    def initialize(size: 10)
      @size = size
      @queue = []
      @fibers = []
    end
    
    # sig { params(block: T.proc.void).void }
    def schedule(&block)
      @queue << block
      process_queue
    end
    
    # sig { void }
    def wait_all
      process_queue until @queue.empty? && @fibers.all? { !_1.alive? }
    end
    
    private
    
    def process_queue
      while @fibers.count(&:alive?) < @size && @queue.any?
        task = @queue.shift
        fiber = Fiber.new { task.call }
        @fibers << fiber
        fiber.resume
      end
      
      @fibers.reject! { !_1.alive? }
    end
  end
  
  # ============================================
  # PARALLEL EXECUTOR using Ractors
  # ============================================
  
  class ParallelExecutor
    # sig { params(items: T::Array[T.untyped], max_workers: Integer, block: T.proc.params(arg0: T.untyped).returns(T.untyped)).returns(T::Array[T.untyped]) }
    def self.map(items, max_workers: 4, &block)
      return items.map(&block) unless NotionForge.parallel
      
      # Ractors require shareable objects
      begin
        ractors = items.first(max_workers).map do |item|
          Ractor.new(item, &block)
        end
        
        ractors.map(&:take)
      rescue => e
        NotionForge.log(:warn, "Ractor failed, falling back to sequential: #{e.message}")
        items.map(&block)
      end
    end
  end
  
  # ============================================
  # LAZY QUERY BUILDER with Pattern Matching
  # ============================================
  
  class QueryBuilder
    include Enumerable
    
    # sig { params(collection: T::Array[T.untyped]).void }
    def initialize(collection)
      @collection = collection
      @filters = []
    end
    
    # sig { params(pattern: T::Hash[Symbol, T.untyped]).returns(QueryBuilder) }
    def where(**pattern)
      @filters << ->(item) do
        case item
        in **pattern then true
        else false
        end
      end
      self
    end
    
    # sig { params(klass: Class).returns(QueryBuilder) }
    def of_type(klass)
      @filters << ->(item) { item.is_a?(klass) }
      self
    end
    
    # sig { params(block: T.proc.params(arg0: T.untyped).returns(T::Boolean)).returns(QueryBuilder) }
    def filter(&block)
      @filters << block
      self
    end
    
    # sig { params(block: T.proc.params(arg0: T.untyped).returns(T.untyped)).returns(T::Array[T.untyped]) }
    def map(&block)
      each.lazy.map(&block).force
    end
    
    # sig { void.returns(T::Enumerator::Lazy[T.untyped]) }
    def lazy
      each.lazy
    end
    
    # sig { params(block: T.proc.params(arg0: T.untyped).void).void }
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
  
  # ============================================
  # BASE RESOURCE CLASS
  # ============================================
  
  class Resource
    attr_reader :id, :properties, :children, :parent_id
    attr_accessor :metadata
    
    # sig { params(id: T.nilable(String), properties: T::Hash[String, T.untyped], children: T::Array[T.untyped], parent_id: T.nilable(String), opts: T.untyped).void }
    def initialize(id: nil, properties: {}, children: [], parent_id: nil, **opts)
      @id = id
      @properties = properties
      @children = children
      @parent_id = parent_id
      @metadata = opts[:metadata] || {}
      @dependencies = []
      @lazy_loaded = false
    end
    
    # Query methods
    # sig { returns(T::Boolean) }
    def exists? = id && client.exists?(resource_path) rescue false
    
    # sig { returns(T::Boolean) }
    def persisted? = !id.nil?
    
    # sig { returns(T::Boolean) }
    def archived? = properties.dig('archived') == true
    
    # sig { returns(T::Boolean) }
    def lazy_loaded? = @lazy_loaded
    
    # Pattern matching support
    def deconstruct = [id, properties, metadata]
    
    def deconstruct_keys(keys)
      {
        id: id,
        properties: properties,
        metadata: metadata,
        type: resource_type
      }
    end
    
    # CRUD operations with Fiber support
    # sig { returns(Resource) }
    def fetch!
      raise ResourceNotFoundError, "Cannot fetch without ID" unless id
      
      Fiber.yield if Fiber.current != Fiber.main
      
      @properties = client.get(resource_path)
      @lazy_loaded = true
      self
    end
    
    # sig { returns(Resource) }
    def create!
      log "Creating #{resource_type} '#{name}'..."
      
      Fiber.yield if Fiber.current != Fiber.main
      
      response = client.post(create_path, body: to_notion)
      @id = response['id']
      state.save(state_key, id, metadata: metadata_for_state)
      log_success "Created #{resource_type} '#{name}'"
      self
    end
    
    # sig { returns(Resource) }
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
    
    # sig { params(updates: T::Hash[Symbol, T.untyped]).returns(Resource) }
    def update!(**updates)
      raise ResourceNotFoundError, "Cannot update without ID" unless id
      
      Fiber.yield if Fiber.current != Fiber.main
      
      @properties.merge!(updates)
      client.patch(resource_path, body: updates)
      self
    end
    
    # sig { returns(Resource) }
    def archive! = update!(archived: true)
    
    # sig { returns(Resource) }
    def restore! = update!(archived: false)
    
    # sig { returns(Resource) }
    def reload!
      fetch!
      self
    end
    
    # Lazy loading with memoization
    # sig { returns(Resource) }
    def load!
      return self if lazy_loaded?
      fetch!
    end
    
    # Dependency management
    # sig { params(resources: T::Array[Resource]).returns(Resource) }
    def depends_on(*resources)
      @dependencies.concat(resources)
      self
    end
    
    # sig { returns(Resource) }
    def resolve_dependencies!
      if NotionForge.parallel
        ParallelExecutor.map(@dependencies, max_workers: NotionForge.configuration.max_workers, &:find_or_create!)
      else
        @dependencies.each(&:find_or_create!)
      end
      self
    end
    
    # DSL helpers
    # sig { params(opts: T::Hash[Symbol, T.untyped]).returns(Resource) }
    def with(**opts)
      opts.each { |key, value| send(:"#{key}=", value) if respond_to?(:"#{key}=") }
      self
    end
    
    # Async support
    # sig { params(block: T.proc.params(arg0: Resource).void).returns(Fiber) }
    def async(&block)
      Fiber.new do
        block.call(self)
      end.tap(&:resume)
    end
    
    protected
    
    def client = Client.instance
    def state = StateManager.instance
    
    def resource_type = self.class.name.split('::').last.downcase
    def name = 'Unnamed'
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
  
  # ============================================
  # HTTP CLIENT - Singleton
  # ============================================
  
  class Client
    include Singleton
    
    BASE_URI = URI('https://api.notion.com/v1')
    
    class << self
      extend Forwardable
      def_delegators :instance, :get, :post, :patch, :exists?
    end
    
    # sig { params(path: String).returns(T::Hash[String, T.untyped]) }
    def get(path) = request(path, :get)
    
    # sig { params(path: String, body: T::Hash[Symbol, T.untyped]).returns(T::Hash[String, T.untyped]) }
    def post(path, body:) = request(path, :post, body: body)
    
    # sig { params(path: String, body: T::Hash[Symbol, T.untyped]).returns(T::Hash[String, T.untyped]) }
    def patch(path, body:) = request(path, :patch, body: body)
    
    # sig { params(path: String).returns(T::Boolean) }
    def exists?(path) = !get(path)['archived'] rescue false
    
    private
    
    # sig { params(path: String, method: Symbol, body: T.nilable(T::Hash[Symbol, T.untyped])).returns(T::Hash[String, T.untyped]) }
    def request(path, method, body: nil)
      uri = URI.join(BASE_URI, path)
      http = Net::HTTP.new(uri.host, uri.port).tap { _1.use_ssl = true }
      
      req = build_request(uri, method, body)
      res = http.request(req)
      
      handle_response(res)
    end
    
    def build_request(uri, method, body)
      req_class = case method
                  when :get then Net::HTTP::Get
                  when :post then Net::HTTP::Post
                  when :patch then Net::HTTP::Patch
                  end
      
      req_class.new(uri).tap do |req|
        req['Authorization'] = "Bearer #{NotionForge.token}"
        req['Notion-Version'] = NOTION_VERSION
        req['Content-Type'] = 'application/json'
        req.body = body.to_json if body
      end
    end
    
    def handle_response(response)
      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
      
      raise APIError, "HTTP #{response.code}: #{response.body}"
    end
  end
  
  # ============================================
  # STATE MANAGER - Singleton with Lazy Loading
  # ============================================
  
  class StateManager
    include Singleton
    
    attr_reader :data
    
    def initialize
      @data = nil # Lazy load
      @loaded = false
    end
    
    # Lazy loading
    # sig { returns(T::Hash[String, T.untyped]) }
    def data
      load! unless @loaded
      @data
    end
    
    # sig { void }
    def load!
      @data = load_state
      @loaded = true
    end
    
    # Query methods
    # sig { params(key: String).returns(T::Boolean) }
    def exists?(key) = data.dig('resources', key.to_s).present?
    
    # sig { params(key: String).returns(T.nilable(String)) }
    def get_id(key) = data.dig('resources', key.to_s, 'id')
    
    # sig { params(key: String).returns(T.nilable(T::Hash[String, T.untyped])) }
    def get_metadata(key) = data.dig('resources', key.to_s, 'metadata')
    
    # sig { params(key: String).returns(T.untyped) }
    def [](key) = data[key.to_s]
    
    # Mutation methods
    # sig { params(key: String, id: String, metadata: T::Hash[Symbol, T.untyped]).void }
    def save(key, id, metadata: {})
      data['resources'] ||= {}
      data['resources'][key.to_s] = {
        'id' => id,
        'metadata' => metadata
      }
      persist!
    end
    
    # sig { params(key: String, value: T.untyped).void }
    def []=(key, value)
      data[key.to_s] = value
      persist!
    end
    
    # sig { void }
    def clear!
      @data = default_state
      persist!
    end
    
    # sig { params(key: String).void }
    def delete(key)
      data['resources']&.delete(key.to_s)
      persist!
    end
    
    # Lazy enumeration
    # sig { returns(T::Enumerator::Lazy[T::Array[String, T::Hash[String, T.untyped]]]) }
    def each_resource
      return enum_for(:each_resource).lazy unless block_given?
      
      data.fetch('resources', {}).each do |key, value|
        yield [key, value]
      end
    end
    
    private
    
    def load_state
      return default_state unless File.exist?(state_file)
      YAML.load_file(state_file) || default_state
    rescue => e
      warn "Failed to load state: #{e.message}"
      default_state
    end
    
    def default_state = { 'resources' => {}, 'version' => VERSION }
    def persist! = File.write(state_file, data.to_yaml)
    def state_file = NotionForge.state_file
  end
  
  # ============================================
  # PAGE - Notion Page Resource
  # ============================================
  
  class Page < Resource
    attr_accessor :title, :icon, :cover
    
    # sig { params(title: String, parent_id: T.nilable(String), icon: T.nilable(String), cover: T.nilable(String), opts: T.untyped).void }
    def initialize(title:, parent_id: nil, icon: nil, cover: nil, **opts)
      super(parent_id: parent_id, **opts)
      @title = title
      @icon = icon
      @cover = cover
    end
    
    # Builder DSL
    # sig { params(blocks: T::Array[T::Hash[Symbol, T.untyped]]).returns(Page) }
    def add(*blocks)
      @children.concat(blocks)
      self
    end
    
    alias_method :<<, :add
    
    # sig { params(block: T.proc.void).returns(Page) }
    def build(&block)
      PageBuilder.new(self).instance_eval(&block) if block
      self
    end
    
    protected
    
    def name = title
    def resource_path = "/pages/#{id}"
    def create_path = '/pages'
    
    def to_notion
      {
        parent: { page_id: parent_id },
        properties: { title: { title: [{ text: { content: title } }] } },
        icon: icon ? { emoji: icon } : nil,
        cover: cover ? { type: 'external', external: { url: cover } } : nil,
        children: children.any? ? children : nil
      }.compact
    end
  end
  
  # ============================================
  # DATABASE - Notion Database Resource
  # ============================================
  
  class Database < Resource
    attr_accessor :title, :icon, :schema, :relations
    
    # sig { params(title: String, parent_id: T.nilable(String), icon: T.nilable(String), schema: T::Hash[String, T.untyped], opts: T.untyped).void }
    def initialize(title:, parent_id: nil, icon: nil, schema: {}, **opts)
      super(parent_id: parent_id, **opts)
      @title = title
      @icon = icon
      @schema = schema
      @relations = {}
    end
    
    # Schema DSL
    # sig { params(name: String, type: Symbol, opts: T.untyped).returns(Database) }
    def prop(name, type, **opts)
      @schema[name] = Property.build(type, **opts)
      self
    end
    
    alias_method :property, :prop
    
    # sig { params(name: String, target_db: Database, synced: T.nilable(String)).returns(Database) }
    def relate(name, target_db, synced: nil)
      @relations[name] = { target: target_db, synced: synced }
      depends_on(target_db)
      self
    end
    
    alias_method :relation, :relate
    
    # sig { returns(Database) }
    def sync_relations!
      return self if relations.empty?
      
      props = relations.transform_values do |config|
        target = config[:target]
        target.find_or_create! unless target.persisted?
        
        {
          relation: {
            database_id: target.id,
            type: 'dual_property',
            dual_property: {}
          }
        }
      end
      
      update!(properties: props)
    end
    
    # Template factory
    # sig { params(title: String, icon: T.nilable(String), props: T::Hash[String, T.untyped], block: T.nilable(T.proc.void)).returns(Template) }
    def template(title, icon: nil, props: {}, &block)
      Template.new(
        title: title,
        database_id: id,
        icon: icon,
        properties: props,
        &block
      )
    end
    
    protected
    
    def name = title
    def resource_path = "/databases/#{id}"
    def create_path = '/databases'
    
    def to_notion
      {
        parent: { page_id: parent_id },
        title: [{ text: { content: title } }],
        properties: schema,
        icon: icon ? { emoji: icon } : nil
      }.compact
    end
  end
  
  # ============================================
  # TEMPLATE - Database Template
  # ============================================
  
  class Template < Resource
    attr_accessor :title, :database_id, :icon, :template_props
    
    # sig { params(title: String, database_id: String, icon: T.nilable(String), properties: T::Hash[String, T.untyped], opts: T.untyped, block: T.nilable(T.proc.void)).void }
    def initialize(title:, database_id:, icon: nil, properties: {}, **opts, &block)
      super(**opts)
      @title = title
      @database_id = database_id
      @icon = icon
      @template_props = properties
      
      build(&block) if block
    end
    
    # sig { params(block: T.proc.void).returns(Template) }
    def build(&)
      PageBuilder.new(self).instance_eval(&) if block_given?
      self
    end
    
    protected
    
    def name = title
    def resource_path = "/pages/#{id}"
    def create_path = '/pages'
    
    def to_notion
      {
        parent: { database_id: database_id },
        properties: build_props,
        icon: icon ? { emoji: icon } : nil,
        children: children.any? ? children : nil
      }.compact
    end
    
    def build_props
      base = { 'Tytuł' => { title: [{ text: { content: title } }] } }
      
      template_props.each do |key, value|
        base[key] = case value
                    when Hash then value
                    else { select: { name: value.to_s } }
                    end
      end
      
      base
    end
  end
  
  # ============================================
  # PROPERTY BUILDERS - Type-safe DSL
  # ============================================
  
  module Property
    extend self
    
    # sig { params(type: Symbol, opts: T.untyped).returns(T::Hash[Symbol, T.untyped]) }
    def build(type, **opts)
      send(type, **opts)
    rescue NoMethodError
      raise ArgumentError, "Unknown property type: #{type}"
    end
    
    # Define properties with metaprogramming
    {
      title: -> { { title: {} } },
      text: -> { { rich_text: {} } },
      checkbox: -> { { checkbox: {} } },
      url: -> { { url: {} } },
      email: -> { { email: {} } },
      phone: -> { { phone_number: {} } },
      date: -> { { date: {} } },
      files: -> { { files: {} } },
      created_time: -> { { created_time: {} } },
      created_by: -> { { created_by: {} } },
      last_edited_time: -> { { last_edited_time: {} } },
      last_edited_by: -> { { last_edited_by: {} } }
    }.each do |name, builder|
      define_method(name, &builder)
    end
    
    # sig { params(format: String).returns(T::Hash[Symbol, T.untyped]) }
    def number(format: 'number')
      { number: { format: format } }
    end
    
    # sig { params(options: T::Array[T.any(String, T::Hash[Symbol, T.untyped])]).returns(T::Hash[Symbol, T.untyped]) }
    def select(options: [])
      {
        select: {
          options: normalize_options(options)
        }
      }
    end
    
    # sig { params(options: T::Array[T.any(String, T::Hash[Symbol, T.untyped])]).returns(T::Hash[Symbol, T.untyped]) }
    def multi_select(options: [])
      {
        multi_select: {
          options: normalize_options(options)
        }
      }
    end
    
    # sig { params(options: T::Array[T.any(String, T::Hash[Symbol, T.untyped])]).returns(T::Hash[Symbol, T.untyped]) }
    def status(options: [])
      {
        status: {
          options: normalize_options(options)
        }
      }
    end
    
    # sig { params(database_id: String).returns(T::Hash[Symbol, T.untyped]) }
    def relation(database_id:)
      {
        relation: {
          database_id: database_id
        }
      }
    end
    
    private
    
    def normalize_options(opts)
      opts.map do |opt|
        case opt
        in { name:, color: } then opt
        in { name: } then { name: opt[:name], color: 'default' }
        in String then { name: opt, color: 'default' }
        else { name: opt.to_s, color: 'default' }
        end
      end
    end
  end
  
  # ============================================
  # BLOCK BUILDERS - Content DSL with Macros
  # ============================================
  
  module Block
    extend self
    
    # sig { params(level: Integer, text: String, opts: T.untyped).returns(T::Hash[Symbol, T.untyped]) }
    def heading(level, text, **opts)
      raise ArgumentError, "Level must be 1-3" unless (1..3).include?(level)
      
      {
        object: 'block',
        type: "heading_#{level}",
        "heading_#{level}": {
          rich_text: [{ text: { content: text } }],
          **opts
        }
      }
    end
    
    # Generate h1, h2, h3 methods with define_method
    (1..3).each do |level|
      define_method(:"h#{level}") do |text, **opts|
        heading(level, text, **opts)
      end
    end
    
    # sig { params(text: String, opts: T.untyped).returns(T::Hash[Symbol, T.untyped]) }
    def paragraph(text, **opts)
      {
        object: 'block',
        type: 'paragraph',
        paragraph: {
          rich_text: [{ text: { content: text } }],
          **opts
        }
      }
    end
    
    alias_method :p, :paragraph
    
    # sig { params(emoji: String, text: String, color: String).returns(T::Hash[Symbol, T.untyped]) }
    def callout(emoji, text, color: 'gray_background')
      {
        object: 'block',
        type: 'callout',
        callout: {
          icon: { emoji: emoji },
          color: color,
          rich_text: [{ text: { content: text } }]
        }
      }
    end
    
    # sig { returns(T::Hash[Symbol, T.untyped]) }
    def divider
      {
        object: 'block',
        type: 'divider',
        divider: {}
      }
    end
    
    alias_method :hr, :divider
    
    # sig { params(text: String, checked: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
    def todo(text, checked: false)
      {
        object: 'block',
        type: 'to_do',
        to_do: {
          rich_text: [{ text: { content: text } }],
          checked: checked
        }
      }
    end
    
    # sig { params(text: String).returns(T::Hash[Symbol, T.untyped]) }
    def quote(text)
      {
        object: 'block',
        type: 'quote',
        quote: {
          rich_text: [{ text: { content: text } }]
        }
      }
    end
    
    # sig { params(text: String).returns(T::Hash[Symbol, T.untyped]) }
    def bullet(text)
      {
        object: 'block',
        type: 'bulleted_list_item',
        bulleted_list_item: {
          rich_text: [{ text: { content: text } }]
        }
      }
    end
    
    alias_method :li, :bullet
    
    # sig { params(text: String).returns(T::Hash[Symbol, T.untyped]) }
    def numbered(text)
      {
        object: 'block',
        type: 'numbered_list_item',
        numbered_list_item: {
          rich_text: [{ text: { content: text } }]
        }
      }
    end
    
    alias_method :ol, :numbered
    
    # sig { params(title: String, children: T::Array[T::Hash[Symbol, T.untyped]], block: T.nilable(T.proc.void)).returns(T::Hash[Symbol, T.untyped]) }
    def toggle(title, children = [], &block)
      kids = block ? capture_blocks(&block) : children
      
      {
        object: 'block',
        type: 'toggle',
        toggle: {
          rich_text: [{ text: { content: title } }],
          children: kids
        }
      }
    end
    
    # sig { params(text: String, language: String).returns(T::Hash[Symbol, T.untyped]) }
    def code(text, language: 'ruby')
      {
        object: 'block',
        type: 'code',
        code: {
          rich_text: [{ text: { content: text } }],
          language: language
        }
      }
    end
    
    # Macro: Create multiple blocks at once
    # sig { params(items: T::Array[String], block_type: Symbol).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
    def list(items, block_type: :bullet)
      items.map { |item| send(block_type, item) }
    end
    
    private
    
    def capture_blocks(&block)
      builder = PageBuilder.new(Page.new(title: '', parent_id: ''))
      builder.instance_eval(&block)
      builder.instance_variable_get(:@page).children
    end
  end
  
  # ============================================
  # WORKSPACE - Main Builder with Parallel Support
  # ============================================
  
  class Workspace
    attr_reader :root, :resources
    
    # sig { params(title: String, parent_id: T.nilable(String), icon: String, cover: T.nilable(String), block: T.nilable(T.proc.void)).void }
    def initialize(title:, parent_id: nil, icon: '🏛️', cover: nil, &block)
      @root = Page.new(
        title: title,
        parent_id: parent_id || NotionForge.parent_page_id,
        icon: icon,
        cover: cover
      )
      @resources = []
      @fiber_pool = FiberPool.new(size: 10)
      
      instance_eval(&block) if block
    end
    
    # Resource factories
    # sig { params(title: String, icon: T.nilable(String), block: T.nilable(T.proc.void)).returns(Database) }
    def database(title, icon: nil, &block)
      db = Database.new(title: title, parent_id: root.id, icon: icon)
      DatabaseBuilder.new(db).instance_eval(&block) if block
      @resources << db
      db
    end
    
    # sig { params(title: String, icon: T.nilable(String), cover: T.nilable(String), block: T.nilable(T.proc.void)).returns(Page) }
    def page(title, icon: nil, cover: nil, &block)
      pg = Page.new(title: title, parent_id: root.id, icon: icon, cover: cover)
      pg.build(&block) if block
      @resources << pg
      pg
    end
    
    # Query builder for resources
    # sig { returns(QueryBuilder) }
    def query
      QueryBuilder.new(@resources)
    end
    
    # Pattern matching queries
    # sig { params(pattern: T::Hash[Symbol, T.untyped]).returns(T::Array[Resource]) }
    def find(**pattern)
      query.where(**pattern).to_a
    end
    
    # sig { params(klass: Class).returns(T::Array[Resource]) }
    def find_by_type(klass)
      query.of_type(klass).to_a
    end
    
    # Lazy enumeration
    # sig { returns(T::Enumerator::Lazy[Resource]) }
    def each_resource
      @resources.lazy
    end
    
    # Build strategies
    # sig { params(mode: Symbol).void }
    def forge!(mode: :update)
      puts "🔥 Forging workspace: #{root.title}"
      puts "   Mode: #{mode_emoji(mode)} #{mode.to_s.capitalize}"
      puts "   Parallel: #{NotionForge.parallel ? 'Yes' : 'No'}\n\n"
      
      case mode
      when :fresh then return if root.exists?
      when :force then reset_workspace!
      end
      
      root.find_or_create!
      @resources.each { |r| r.parent_id ||= root.id }
      
      if NotionForge.parallel
        forge_parallel!
      else
        forge_sequential!
      end
      
      sync_relations!
      print_summary
    end
    
    alias_method :build!, :forge!
    
    # Async forging with Fibers
    # sig { params(mode: Symbol, block: T.proc.params(arg0: Workspace).void).returns(Fiber) }
    def forge_async!(mode: :update, &block)
      Fiber.new do
        forge!(mode: mode)
        block.call(self) if block
      end.tap(&:resume)
    end
    
    private
    
    def forge_sequential!
      @resources.each do |resource|
        resource.resolve_dependencies!
        resource.find_or_create!
      end
    end
    
    def forge_parallel!
      NotionForge.log(:info, "Forging resources in parallel (#{NotionForge.configuration.max_workers} workers)...")
      
      # Resolve dependencies first
      @resources.each(&:resolve_dependencies!)
      
      # Create resources in parallel
      ParallelExecutor.map(
        @resources,
        max_workers: NotionForge.configuration.max_workers,
        &:find_or_create!
      )
    end
    
    def sync_relations!
      databases.each(&:sync_relations!)
    end
    
    def reset_workspace!
      root.archive! if root.exists?
      StateManager.instance.clear!
    end
    
    def databases = @resources.select { _1.is_a?(Database) }
    def pages = @resources.select { _1.is_a?(Page) }
    
    def mode_emoji(mode)
      case mode
      when :fresh then '🆕'
      when :update then '🔄'
      when :force then '⚠️'
      end
    end
    
    def print_summary
      puts "\n" + "="*60
      puts "🎉 WORKSPACE FORGED!"
      puts "="*60
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
      in [_, dbs, _] if dbs > 5
        puts "\n📚 Database-heavy workspace (#{dbs} databases)"
      else
        puts "\n✨ Workspace looks great!"
      end
      
      puts "="*60
    end
  end
  
  # ============================================
  # BUILDERS - DSL Helpers with Magic
  # ============================================
  
  class DatabaseBuilder
    # sig { params(database: Database).void }
    def initialize(database)
      @database = database
    end
    
    # sig { params(args: T.untyped, kwargs: T.untyped).returns(Database) }
    def prop(...) = @database.prop(...)
    
    # sig { params(args: T.untyped, kwargs: T.untyped).returns(Database) }
    def relate(...) = @database.relate(...)
    
    alias_method :property, :prop
    alias_method :relation, :relate
    
    # sig { params(title: String, icon: T.nilable(String), props: T::Hash[String, T.untyped], block: T.nilable(T.proc.void)).returns(Template) }
    def template(title, icon: nil, props: {}, &block)
      tmpl = @database.template(title, icon: icon, props: props, &block)
      tmpl.database_id = @database.id
      tmpl.find_or_create!
      tmpl
    end
    
    # Magic method_missing for property types
    def method_missing(method, *args, **kwargs, &block)
      if Property.respond_to?(method, true)
        name = args.first || method.to_s.capitalize
        prop(name, method, **kwargs)
      else
        super
      end
    end
    
    def respond_to_missing?(method, include_private = false)
      Property.respond_to?(method, true) || super
    end
  end
  
  class PageBuilder
    # sig { params(page: T.any(Page, Template)).void }
    def initialize(page)
      @page = page
    end
    
    # Delegate all Block methods
    Block.public_methods(false).each do |method|
      define_method(method) do |*args, **kwargs, &block|
        @page.children << Block.send(method, *args, **kwargs, &block)
      end
    end
    
    # DSL macro: Create section with header and content
    # sig { params(title: String, level: Integer, block: T.proc.void).void }
    def section(title, level: 2, &block)
      @page.children << Block.heading(level, title)
      instance_eval(&block) if block
      @page.children << Block.divider
    end
    
    # DSL macro: Create expandable section
    # sig { params(title: String, block: T.proc.void).void }
    def expandable(title, &block)
      content = if block
        builder = PageBuilder.new(Page.new(title: '', parent_id: ''))
        builder.instance_eval(&block)
        builder.instance_variable_get(:@page).children
      else
        []
      end
      
      @page.children << Block.toggle(title, content)
    end
    
    # sig { params(block: T::Hash[Symbol, T.untyped]).void }
    def raw(block)
      @page.children << block
    end
  end
  
  # ============================================
  # COLLECTION HELPERS with Lazy Evaluation
  # ============================================
  
  class ResourceCollection
    include Enumerable
    
    # sig { params(resources: T::Array[Resource]).void }
    def initialize(resources)
      @resources = resources
    end
    
    # sig { params(block: T.proc.params(arg0: Resource).void).void }
    def each(&block)
      return enum_for(:each) unless block
      @resources.each(&block)
    end
    
    # sig { returns(T::Enumerator::Lazy[Resource]) }
    def lazy = @resources.lazy
    
    # Pattern matching
    # sig { params(pattern: T::Hash[Symbol, T.untyped]).returns(ResourceCollection) }
    def where(**pattern)
      filtered = select do |resource|
        case resource
        in **pattern then true
        else false
        end
      end
      ResourceCollection.new(filtered)
    end
    
    # sig { returns(T::Array[Database]) }
    def databases = select { _1.is_a?(Database) }
    
    # sig { returns(T::Array[Page]) }
    def pages = select { _1.is_a?(Page) }
    
    # Parallel operations
    # sig { params(max_workers: Integer, block: T.proc.params(arg0: Resource).returns(T.untyped)).returns(T::Array[T.untyped]) }
    def parallel_map(max_workers: 4, &block)
      ParallelExecutor.map(@resources, max_workers: max_workers, &block)
    end
  end
end

# ============================================
# DSL EXTENSIONS - Top-level convenience
# ============================================

module NotionForgeDSL
  # sig { params(title: String, opts: T.untyped, block: T.proc.void).returns(NotionForge::Workspace) }
  def forge_workspace(title, **opts, &block)
    NotionForge::Workspace.new(title: title, **opts, &block)
  end
  
  # sig { params(resources: T::Array[NotionForge::Resource]).returns(NotionForge::QueryBuilder) }
  def query(resources)
    NotionForge::QueryBuilder.new(resources)
  end
end

# ============================================
# EXAMPLE WORKSPACE - Philosophical Workshop
# ============================================

def forge_philosophical_workspace
  NotionForge::Workspace.new(
    title: 'Philosophical Workshop',
    icon: '🏛️',
    cover: 'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=1500'
  ) do
    
    # Publications database with full DSL
    publications = database 'Publications', icon: '📝' do
      title
      status options: [
        { name: '📋 Draft', color: 'gray' },
        { name: '🔍 Research', color: 'brown' },
        { name: '🏗️ Structure', color: 'orange' },
        { name: '✍️ Writing', color: 'yellow' },
        { name: '🔧 Review', color: 'blue' },
        { name: '✅ Done', color: 'green' }
      ]
      select 'Type', options: ['🗡️ Polemic', '📄 Article', '💬 Comment']
      select 'Priority', options: ['🔥 Urgent', '⚡ High', '📌 Medium', '💤 Low']
      created_time
      date 'Published'
      url 'Link'
      number 'Word Count'
      
      template '[TEMPLATE] Polemic', icon: '🗡️', props: { 'Type' => '🗡️ Polemic' } do
        callout '🗡️', 'POLEMIC - Response to specific text', color: 'red_background'
        
        section 'Source Analysis' do
          h3 '📄 Source Text'
          p '[Link to interlocutor text]'
          h3 '👤 Author Background'
          p '[Who is the author?]'
        end
        
        section 'Main Theses', level: 2 do
          ol 'Thesis 1'
          ol 'Thesis 2'
          ol 'Thesis 3'
        end
        
        expandable 'Counter-arguments' do
          ol 'Argument 1 - [brief]'
          p 'Detailed counter...'
          ol 'Argument 2 - [brief]'
          p 'Detailed counter...'
        end
        
        hr
        
        h2 '✍️ Draft Section'
        p '[Start writing here...]'
      end
    end
    
    # Sources database
    sources = database 'Sources & References', icon: '📚' do
      title
      text 'Author'
      url 'URL'
      select 'Type', options: ['📖 Book', '🎓 Paper', '📰 Article', '🐦 Tweet']
      select 'Utility', options: ['🔥 Key', '⭐ Very Useful', '👍 Useful']
      select 'Credibility', options: ['✅ High', '👌 Medium', '⚠️ Verify']
      created_time 'Added'
      date 'Read Date'
      checkbox 'Cited'
      
      template '[TEMPLATE] Source', icon: '📖' do
        section 'Overview' do
          p 'Author: '
          p 'Year: '
          p 'Type: '
        end
        
        section 'Key Quotes' do
          quote 'Quote 1...'
          p '↳ My note: '
          hr
          quote 'Quote 2...'
          p '↳ My note: '
        end
        
        expandable 'Full Notes' do
          p 'Detailed analysis...'
        end
      end
    end
    
    # Conclusions database
    conclusions = database 'Conclusions & Theses', icon: '💡' do
      title 'Thesis'
      select 'Category', options: ['✅ Argument', '❌ Counter', '💡 Conclusion', '🎯 Assumption']
      select 'Strength', options: ['🔥 Very Strong', '💪 Strong', '👌 Medium', '🤔 Weak']
      multi_select 'Philosophy', options: ['Spinoza', 'Realism', 'Anti-idealism', 'Geometry']
      created_time 'Created'
      text 'Full Development'
      
      template '[TEMPLATE] Thesis', icon: '💡' do
        callout '💡', 'Core thesis in one sentence', color: 'yellow_background'
        
        section 'Development' do
          p 'Why do I believe this?'
          p ''
        end
        
        section 'Supporting Sources' do
          li 'Source 1'
          li 'Source 2'
        end
        
        expandable 'Counter-arguments & Defense' do
          h3 '🤔 Possible Objections'
          p 'Who might disagree?'
          hr
          h3 '🛡️ My Defense'
          p 'How to respond?'
        end
      end
    end
    
    # Setup relations
    publications.relate('Sources', sources)
    publications.relate('Conclusions', conclusions)
    sources.relate('Publications', publications)
    
    # Dashboard with advanced layout
    page 'Dashboard', icon: '📊' do
      callout '👋', 'Welcome to your command center!', color: 'blue_background'
      
      hr
      
      section 'Active Work', level: 1 do
        p 'Your current projects appear here'
        toggle 'Quick Stats' do
          li 'Publications in progress: __'
          li 'Sources to read: __'
          li 'Pending reviews: __'
        end
      end
      
      section 'Quick Capture', level: 1 do
        callout '⚡', 'Catch that thought!', color: 'yellow_background'
        p 'Click + to add a quick note'
      end
      
      hr
      
      h2 '🎯 This Week\'s Goals'
      todo 'Finish article X'
      todo 'Read 3 new sources'
      todo 'Review polemic draft'
    end
    
    # Workflow guide
    page 'Workflow Guide', icon: '🔄' do
      callout '📚', 'Complete guide to the creation process', color: 'blue_background'
      
      section 'Publication Stages', level: 1 do
        expandable '📋 Stage 1: Draft/Notes (15-30 min)' do
          p 'Record initial thoughts'
          li 'Don\'t worry about structure'
          li 'Capture key ideas'
          li 'Note questions to explore'
        end
        
        expandable '🔍 Stage 2: Research (1-2h)' do
          p 'Gather supporting materials'
          li 'Find 3-5 key sources'
          li 'Take structured notes'
          li 'Identify quotes'
        end
        
        expandable '🏗️ Stage 3: Structure (30 min)' do
          p 'Plan the argument flow'
          li 'Outline main points'
          li 'Order arguments'
          li 'Plan transitions'
        end
        
        expandable '✍️ Stage 4: Writing (2-4h)' do
          p 'First draft'
          li 'Focus on content'
          li 'Don\'t edit yet'
          li 'Get ideas on page'
        end
        
        expandable '🔧 Stage 5: Review (1h)' do
          p 'Polish and perfect'
          li 'Check logic'
          li 'Verify sources'
          li 'Add style elements'
        end
        
        expandable '✅ Stage 6: Done!' do
          p 'Ready for publication'
          li 'Final read-through'
          li 'Publish'
          li 'Track engagement'
        end
      end
      
      hr
      
      h2 '💡 Pro Tips'
      quote 'Take breaks between stages for fresh perspective'
      quote 'Read drafts aloud to catch awkward phrasing'
      quote 'Keep a running list of future topics'
    end
    
    # Style guide
    page 'Style Guide', icon: '🎨' do
      callout '✍️', 'Your writing voice and philosophy', color: 'purple_background'
      
      section 'Core Characteristics' do
        toggle 'Philosophical Dignity' do
          li 'Use precise philosophical terminology'
          li 'Reference Spinoza, realism, geometry'
          li 'Apply Occam\'s Razor to arguments'
        end
        
        toggle 'Subtle Humor' do
          li 'Ironic commentary on idealists'
          li 'Witty juxtapositions'
          li 'Light touch - flavor not farce'
        end
      end
      
      section 'Favorite Techniques' do
        li '**Contrasts** - Expose absurd narratives'
        li '**Heuristics over mysticism** - Reduce "genius" to principles'
        li '**Geometry vs ideology** - Show structural necessities'
        li '**Resource economics** - Everything is cost/benefit'
      end
      
      hr
      
      h2 '❌ Avoid'
      li 'Mythologizing individuals'
      li 'Teleological explanations'
      li 'Uncritical idealist vocabulary'
      li 'Overly complex sentences'
    end
  end
end

# ============================================
# CLI with Advanced Options
# ============================================

if __FILE__ == $0
  options = {
    mode: :update,
    verbose: false,
    parallel: false,
    max_workers: 4
  }
  
  OptionParser.new do |opts|
    opts.banner = <<~BANNER
      🔥 NotionForge v#{NotionForge::VERSION}
      Infrastructure as Code for Notion
      
      Usage: ruby notionforge.rb [options]
    BANNER
    
    opts.on("--fresh", "Create workspace only if doesn't exist") do
      options[:mode] = :fresh
    end
    
    opts.on("--update", "Add missing elements (default, idempotent)") do
      options[:mode] = :update
    end
    
    opts.on("--force", "Delete old workspace and create new") do
      options[:mode] = :force
    end
    
    opts.on("-v", "--verbose", "Verbose output") do
      options[:verbose] = true
    end
    
    opts.on("-p", "--parallel", "Enable parallel resource creation (experimental)") do
      options[:parallel] = true
    end
    
    opts.on("-w", "--workers N", Integer, "Number of parallel workers (default: 4)") do |n|
      options[:max_workers] = n
    end
    
    opts.on("-c", "--config FILE", "Load config from file") do |file|
      options[:config_file] = file
    end
    
    opts.on("-h", "--help", "Show this help") do
      puts opts
      exit
    end
    
    opts.on("--version", "Show version") do
      puts "NotionForge v#{NotionForge::VERSION}"
      exit
    end
  end.parse!
  
  # Load configuration
  config_file = options[:config_file] || 'notionforge.yml'
  
  if File.exist?(config_file)
    config = YAML.load_file(config_file)
    NotionForge.configure do |c|
      c.token = config['token']
      c.parent_page_id = config['parent_page_id']
      c.verbose = options[:verbose]
      c.parallel = options[:parallel]
      c.max_workers = options[:max_workers]
    end
  else
    NotionForge.configure do |c|
      c.token = ENV['NOTION_TOKEN']
      c.parent_page_id = ENV['NOTION_PARENT_PAGE_ID']
      c.verbose = options[:verbose]
      c.parallel = options[:parallel]
      c.max_workers = options[:max_workers]
    end
  end
  
  # Validate and build
  begin
    NotionForge.configuration.validate!
    
    puts "🔥 NotionForge v#{NotionForge::VERSION}"
    puts "="*60
    
    workspace = forge_philosophical_workspace
    workspace.forge!(mode: options[:mode])
    
    # Demo pattern matching on results
    case workspace
    in { resources: { count: n } } if n > 10
      puts "\n✨ Large workspace successfully forged!"
    in { resources: [] }
      puts "\n⚠️  Warning: No resources created"
    else
      puts "\n✅ Workspace forged successfully!"
    end
    
  rescue NotionForge::ConfigurationError => e
    puts "❌ Configuration Error: #{e.message}"
    puts "\nCreate #{config_file} with:"
    puts "  token: 'secret_...'"
    puts "  parent_page_id: 'abc123...'"
    puts "\nOr set environment variables:"
    puts "  export NOTION_TOKEN='secret_...'"
    puts "  export NOTION_PARENT_PAGE_ID='abc123...'"
    exit 1
  rescue NotionForge::Error => e
    puts "❌ NotionForge Error: #{e.message}"
    exit 1
  rescue => e
    puts "❌ Unexpected error: #{e.message}"
    puts "\n🔍 Backtrace:"
    puts e.backtrace.first(10).join("\n")
    exit 1
  end
end