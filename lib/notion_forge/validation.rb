# frozen_string_literal: true

require_relative "validation/validation_error"
require_relative "validation/base_validator"
require_relative "validation/method_validator"
require_relative "validation/dsl_validator"
require_relative "validation/api_validator"
require_relative "validation/workspace_validator"

# Core validation module for NotionForge
# Provides centralized validation system to detect issues before deployment
module NotionForge
  module Validation
    # Main validation interface
  end
end
