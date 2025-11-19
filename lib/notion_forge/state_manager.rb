# frozen_string_literal: true

require "yaml"
require "singleton"

using NotionForge::Refinements

module NotionForge
  class StateManager
    include Singleton

    attr_reader :data

    def initialize
      @data = nil # Lazy load
      @loaded = false
    end

    # Lazy loading
    def data
      load! unless @loaded
      @data
    end

    def load!
      @data = load_state
      @loaded = true
    end

    # Query methods
    def exists?(key) = !data.dig("resources", key.to_s).nil? && !data.dig("resources", key.to_s).empty?
    def get_id(key) = data.dig("resources", key.to_s, "id")
    def get_metadata(key) = data.dig("resources", key.to_s, "metadata")
    def [](key) = data[key.to_s]

    # Mutation methods
    def save(key, id, metadata: {})
      data["resources"] ||= {}
      data["resources"][key.to_s] = {
        "id" => id,
        "metadata" => metadata,
      }
      persist!
    end

    def []=(key, value)
      data[key.to_s] = value
      persist!
    end

    def clear!
      @data = default_state
      persist!
    end

    def delete(key)
      data["resources"]&.delete(key.to_s)
      persist!
    end

    # Lazy enumeration
    def each_resource
      return enum_for(:each_resource).lazy unless block_given?

      data.fetch("resources", {}).each do |key, value|
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

    def default_state = { "resources" => {}, "version" => NotionForge::VERSION }
    def persist! = File.write(state_file, data.to_yaml)
    def state_file = NotionForge.state_file
  end
end
