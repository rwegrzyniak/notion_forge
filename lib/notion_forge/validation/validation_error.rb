# frozen_string_literal: true

module NotionForge
  module Validation
    class ValidationError
      attr_reader :code, :message, :fix, :line, :context

      def initialize(code, message, fix: nil, line: nil, context: {})
        @code = code
        @message = message
        @fix = fix
        @line = line
        @context = context
      end

      def to_h
        {
          type: 'error',
          code: @code,
          message: @message,
          fix: @fix,
          line: @line,
          context: @context
        }.compact
      end

      def to_json(*args)
        to_h.to_json(*args)
      end
    end

    class ValidationWarning < ValidationError
      def to_h
        super.merge(type: 'warning')
      end
    end
  end
end
