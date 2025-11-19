# frozen_string_literal: true

module NotionForge
  class Configuration
    attr_accessor :token, :parent_page_id, :state_file, :verbose, :max_workers, :dry_run

    def initialize
      @state_file = ".notionforge.state.yml"
      @verbose = false
      @max_workers = 4 # For non-API operations only
      @dry_run = false
    end

    def valid?
      token && parent_page_id
    end

    def validate!
      raise ConfigurationError, "Missing token" unless token
      raise ConfigurationError, "Missing parent_page_id" unless parent_page_id
    end

    def merge(**opts)
      opts.each { |k, v| send(:"#{k}=", v) if respond_to?(:"#{k}=") }
      self
    end
  end
end
