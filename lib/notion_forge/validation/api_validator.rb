# frozen_string_literal: true

module NotionForge
  module Validation
    class ApiValidator < BaseValidator
      def initialize(workspace_instance = nil, context = {})
        super(context)
        @workspace = workspace_instance
      end

      def validate
        validate_authentication
        validate_workspace_limits if @workspace
        validate_property_limits if @workspace
      end

      private

      def validate_authentication
        # Check if configuration exists
        unless defined?(NotionForge.configuration) && NotionForge.configuration
          add_error(
            'missing_configuration',
            'NotionForge configuration is not set up',
            fix: 'Initialize NotionForge.configure block in your application'
          )
          return
        end

        # Check if API token is configured
        unless NotionForge.configuration.respond_to?(:notion_token) && 
               NotionForge.configuration.notion_token
          add_error(
            'missing_auth_token',
            'Notion API token is not configured',
            fix: 'Set NotionForge.configuration.notion_token = "your_token"'
          )
        end
      end

      def validate_workspace_limits
        return unless @workspace.respond_to?(:databases)

        database_count = @workspace.databases.count
        page_count = @workspace.pages.count
        total_resources = @workspace.resources.count

        # API limits validation
        if database_count > 100
          add_warning(
            'too_many_databases',
            "Workspace contains #{database_count} databases, which may hit API limits (recommended: < 100)",
            fix: 'Consider splitting into multiple workspaces'
          )
        end

        if page_count > 500
          add_warning(
            'too_many_pages',
            "Workspace contains #{page_count} pages, which may hit API limits (recommended: < 500)",
            fix: 'Consider splitting into multiple workspaces or using sub-pages'
          )
        end

        if total_resources > 1000
          add_warning(
            'too_many_resources',
            "Workspace contains #{total_resources} total resources, which may cause performance issues",
            fix: 'Consider splitting into smaller workspaces'
          )
        end
      end

      def validate_property_limits
        return unless @workspace.respond_to?(:databases)

        @workspace.databases.each do |database|
          next unless database.respond_to?(:properties)
          
          property_count = database.properties.count
          
          if property_count > 50
            add_warning(
              'too_many_properties',
              "Database '#{database_title(database)}' has #{property_count} properties, which may hit API limits (recommended: < 50)",
              fix: 'Consider reducing the number of properties or splitting the database'
            )
          end

          # Validate individual property types
          validate_property_types(database) if database.properties.respond_to?(:each)
        end
      end

      def validate_property_types(database)
        unsupported_types = []
        
        database.properties.each do |property|
          property_type = extract_property_type(property)
          property_name = extract_property_name(property)
          
          unless supported_property_type?(property_type)
            unsupported_types << {
              database: database_title(database),
              property: property_name,
              type: property_type
            }
          end
        end

        unsupported_types.each do |item|
          add_error(
            'unsupported_property_type',
            "Unsupported property type '#{item[:type]}' in database '#{item[:database]}', property '#{item[:property]}'",
            fix: 'Use supported property types: title, text, select, multi_select, date, number, email, phone_number, url, checkbox, created_time, last_edited_time'
          )
        end
      end

      def supported_property_type?(type)
        supported_types = %w[
          title text select multi_select status date number 
          email phone_number url checkbox created_time 
          last_edited_time people files relation rollup formula
        ]
        supported_types.include?(type.to_s.downcase)
      end

      def database_title(database)
        if database.respond_to?(:title)
          database.title
        elsif database.respond_to?(:name)
          database.name
        else
          'Unknown Database'
        end
      end

      def extract_property_type(property)
        if property.respond_to?(:type)
          property.type
        elsif property.is_a?(Hash) && property[:type]
          property[:type]
        else
          'unknown'
        end
      end

      def extract_property_name(property)
        if property.respond_to?(:name)
          property.name
        elsif property.is_a?(Hash) && property[:name]
          property[:name]
        else
          'Unknown Property'
        end
      end
    end
  end
end
