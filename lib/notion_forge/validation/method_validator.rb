# frozen_string_literal: true

module NotionForge
  module Validation
    class MethodValidator < BaseValidator
      REQUIRED_METHODS = {
        'to_notion_url' => {
          class: String,
          description: 'Convert strings to Notion-compatible URLs',
          introduced_in: '1.2.0',
          fallback: 'Use plain strings instead of URL objects'
        },
        'status_property' => {
          class: 'NotionForge::Property',
          description: 'Create status properties with options',
          introduced_in: '1.1.0',
          fallback: 'Use select properties instead'
        }
      }.freeze

      def validate
        REQUIRED_METHODS.each do |method_name, config|
          check_method_availability(method_name, config)
        end
      end

      private

      def check_method_availability(method_name, config)
        target_class = resolve_class(config[:class])
        
        unless target_class&.method_defined?(method_name) || target_class&.respond_to?(method_name)
          add_error(
            "missing_method_#{method_name}",
            "Required method '#{method_name}' is not available on #{config[:class]}",
            fix: config[:fallback],
            context: {
              method: method_name,
              target_class: config[:class],
              introduced_in: config[:introduced_in],
              description: config[:description]
            }
          )
        end
      end

      def resolve_class(class_name)
        case class_name
        when String
          Object.const_get(class_name) rescue nil
        when Class
          class_name
        else
          class_name
        end
      end
    end
  end
end
