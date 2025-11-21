# frozen_string_literal: true

require 'ostruct'

module NotionForge
  module Validation
    class WorkspaceValidator < BaseValidator
      def initialize(workspace_or_dsl_code)
        super()
        if workspace_or_dsl_code.is_a?(String)
          @dsl_code = workspace_or_dsl_code
          @workspace = nil
        else
          @workspace = workspace_or_dsl_code
          @dsl_code = nil
        end
      end

      def validate
        if @dsl_code
          validate_dsl_code
        elsif @workspace
          validate_workspace_instance
        else
          add_error(
            'invalid_input',
            'No valid workspace instance or DSL code provided for validation',
            fix: 'Provide either a workspace instance or DSL code string'
          )
        end
      end

      def validation_report
        validate unless @errors.any? || @warnings.any?
        
        {
          status: valid? ? 'valid' : 'invalid',
          has_warnings: has_warnings?,
          errors: @errors.map(&:to_h),
          warnings: @warnings.map(&:to_h),
          summary: {
            total_errors: @errors.count,
            total_warnings: @warnings.count,
            critical_issues: @errors.select { |e| e.code.include?('missing_method') || e.code.include?('syntax_error') }.count,
            validation_type: @dsl_code ? 'dsl_code' : 'workspace_instance'
          }
        }
      end

      private

      def validate_dsl_code
        # Validate DSL syntax and structure
        dsl_validator = DslValidator.new(@dsl_code)
        dsl_validator.validate

        # Combine DSL validation results
        @errors.concat(dsl_validator.errors)
        @warnings.concat(dsl_validator.warnings)

        # Run method availability checks
        method_validator = MethodValidator.new
        method_validator.validate
        
        @errors.concat(method_validator.errors)
        @warnings.concat(method_validator.warnings)

        # Try to execute DSL safely to create workspace for API validation
        if valid_so_far?
          begin
            workspace = execute_dsl_safely(@dsl_code)
            if workspace
              api_validator = ApiValidator.new(workspace)
              api_validator.validate
              
              @errors.concat(api_validator.errors)
              @warnings.concat(api_validator.warnings)
            end
          rescue => e
            add_error(
              'dsl_execution_error',
              "DSL code execution failed: #{e.message}",
              fix: 'Fix syntax errors and ensure all referenced methods are available'
            )
          end
        end
      end

      def validate_workspace_instance
        # Run method availability checks
        method_validator = MethodValidator.new
        method_validator.validate

        # Run API compatibility checks
        api_validator = ApiValidator.new(@workspace)
        api_validator.validate

        # Combine results
        @errors.concat(method_validator.errors)
        @errors.concat(api_validator.errors)
        @warnings.concat(method_validator.warnings)
        @warnings.concat(api_validator.warnings)
      end

      def valid_so_far?
        @errors.select { |e| e.code.include?('syntax_error') || e.code.include?('missing_method') }.empty?
      end

      def execute_dsl_safely(dsl_code)
        # Create a safe binding to execute DSL
        safe_binding = create_safe_binding
        
        # Execute the DSL code in safe context
        eval(dsl_code, safe_binding)
        
        # Call forge_workspace method if it exists
        if safe_binding.local_variable_defined?(:forge_workspace) || 
           safe_binding.respond_to?(:forge_workspace)
          safe_binding.eval('forge_workspace')
        else
          nil
        end
      rescue => e
        # Don't re-raise, let the calling method handle this
        nil
      end

      def create_safe_binding
        # Create a minimal binding with NotionForge classes available
        binding_context = Object.new
        binding_context.define_singleton_method(:forge_workspace) { nil }
        
        # Make NotionForge classes available
        binding_context.define_singleton_method(:NotionForge) { ::NotionForge }
        
        binding_context.instance_eval do
          def database(title, **opts, &block)
            # Mock database creation for validation
            OpenStruct.new(title: title, properties: [], **opts)
          end

          def page(title, **opts, &block)
            # Mock page creation for validation
            OpenStruct.new(title: title, **opts)
          end
        end

        binding_context.instance_eval { binding }
      end
    end
  end
end
