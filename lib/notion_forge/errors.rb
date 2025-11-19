# frozen_string_literal: true

module NotionForge
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ResourceNotFoundError < Error; end
  class APIError < Error; end
  class ValidationError < Error; end
end
