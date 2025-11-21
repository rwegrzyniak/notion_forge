# frozen_string_literal: true

module NotionForge
  module Validation
    class BaseValidator
      attr_reader :errors, :warnings, :context

      def initialize(context = {})
        @context = context
        @errors = []
        @warnings = []
      end

      def validate
        raise NotImplementedError, "Subclasses must implement #validate"
      end

      def valid?
        validate if @errors.empty? && @warnings.empty?
        @errors.empty?
      end

      def has_warnings?
        validate if @errors.empty? && @warnings.empty?
        @warnings.any?
      end

      private

      def add_error(code, message, fix: nil, line: nil, context: {})
        @errors << ValidationError.new(code, message, fix: fix, line: line, context: context)
      end

      def add_warning(code, message, fix: nil, line: nil, context: {})
        @warnings << ValidationWarning.new(code, message, fix: fix, line: line, context: context)
      end
    end
  end
end
