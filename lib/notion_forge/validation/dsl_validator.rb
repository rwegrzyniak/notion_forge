# frozen_string_literal: true

module NotionForge
  module Validation
    class DslValidator < BaseValidator
      def initialize(dsl_code, context = {})
        super(context)
        @dsl_code = dsl_code
        @lines = dsl_code.lines
        @parsed_ast = nil
      end

      def validate
        validate_syntax
        validate_structure if valid_syntax?
        validate_property_usage
        validate_common_issues
      end

      private

      def validate_syntax
        begin
          @parsed_ast = RubyVM::InstructionSequence.compile(@dsl_code)
        rescue SyntaxError => e
          add_error(
            'syntax_error',
            "DSL syntax error: #{e.message}",
            fix: 'Fix Ruby syntax errors in the DSL code',
            line: extract_line_number(e.message)
          )
        end
      end

      def valid_syntax?
        !@parsed_ast.nil?
      end

      def validate_structure
        # Check for required forge_workspace method
        forge_method_line = find_line_containing('def forge_workspace')
        unless forge_method_line
          add_error(
            'missing_forge_method',
            'DSL must define a forge_workspace method',
            fix: 'Wrap your workspace definition in: def forge_workspace ... end',
            line: 1
          )
        end

        # Check for workspace initialization
        workspace_init_line = find_line_matching(/NotionForge::Workspace\.new/)
        unless workspace_init_line
          add_error(
            'missing_workspace_init',
            'DSL must create a NotionForge::Workspace instance',
            fix: 'Use: NotionForge::Workspace.new(...) do ... end',
            line: forge_method_line || 1
          )
        end

        # Check for proper block structure
        if workspace_init_line && !find_line_matching(/NotionForge::Workspace\.new.*do\s*$/)
          add_warning(
            'missing_block_structure',
            'Workspace should use block syntax for defining resources',
            fix: 'Use: NotionForge::Workspace.new(...) do ... end',
            line: workspace_init_line
          )
        end
      end

      def validate_property_usage
        # Check for problematic status properties
        status_lines = find_all_lines_matching(/status\s+options:/)
        status_lines.each do |line_num|
          add_warning(
            'status_property_issue',
            'Status properties with options may cause API validation errors',
            fix: 'Use select properties instead: select "Status", options: [...]',
            line: line_num
          )
        end

        # Check for URL properties without proper handling
        if !String.method_defined?(:to_notion_url)
          url_lines = find_all_lines_matching(/url\s+/)
          url_lines.each do |line_num|
            add_error(
              'url_property_unsupported',
              'URL properties require to_notion_url method which is not available',
              fix: 'Remove URL properties or update NotionForge gem version',
              line: line_num
            )
          end
        end
      end

      def validate_common_issues
        # Check for empty option arrays
        empty_options_lines = find_all_lines_matching(/options:\s*\[\s*\]/)
        empty_options_lines.each do |line_num|
          add_warning(
            'empty_options',
            'Found properties with empty options arrays',
            fix: 'Provide at least one option or remove the options parameter',
            line: line_num
          )
        end

        # Check for duplicate property names within database blocks
        validate_duplicate_properties

        # Check for missing database titles
        missing_title_lines = find_all_lines_matching(/database\s+do/)
        missing_title_lines.each do |line_num|
          add_error(
            'missing_database_title',
            'Database definitions require a title parameter',
            fix: 'Use: database "Database Name" do ... end',
            line: line_num
          )
        end

        # Check for relation references to undefined databases
        validate_relation_references
      end

      def validate_duplicate_properties
        # Find each database block with line numbers
        database_starts = find_all_lines_matching(/database\s+(?:"[^"]+"|'[^']+').*do/)
        
        database_starts.each do |db_start_line|
          # Find the corresponding end for this database
          db_end_line = find_matching_end(db_start_line)
          next unless db_end_line
          
          # Extract properties within this database block
          property_names = {}
          
          (db_start_line + 1...db_end_line).each do |line_num|
            line = @lines[line_num - 1]
            if match = line.match(/^\s*(title|text|select|multi_select|status|date|number|email|phone|url|checkbox|created_time)(?:\s+(?:"([^"]+)"|'([^']+)')|(?:\s*$))?/)
              property_type = match[1]
              property_name = match[2] || match[3]
              
              # For properties without explicit names, use the type as the name
              if property_name.nil? || property_name.empty?
                property_name = property_type == 'title' ? 'Title' : property_type.capitalize
              end
              
              if property_names[property_name]
                add_warning(
                  'duplicate_property',
                  "Duplicate property name found: '#{property_name}' (first defined on line #{property_names[property_name]})",
                  fix: 'Ensure all property names are unique within each database',
                  line: line_num
                )
              else
                property_names[property_name] = line_num
              end
            end
          end
        end
      end

      def validate_relation_references
        # Extract database variable assignments with line numbers
        defined_dbs = {}
        @lines.each_with_index do |line, index|
          if match = line.match(/(\w+)\s*=\s*database/)
            defined_dbs[match[1]] = index + 1
          end
        end

        # Check relate statements with line numbers
        @lines.each_with_index do |line, index|
          if match = line.match(/relate\s+(?:"[^"]+"|'[^']+'),\s*(\w+)/)
            referenced_db = match[1]
            unless defined_dbs.key?(referenced_db)
              add_error(
                'undefined_relation_reference',
                "Relation references undefined database variable: '#{referenced_db}'",
                fix: "Ensure '#{referenced_db}' is defined before using it in relations",
                line: index + 1
              )
            end
          end
        end
      end

      # Helper methods for line number tracking
      def find_line_containing(text)
        @lines.each_with_index do |line, index|
          return index + 1 if line.include?(text)
        end
        nil
      end

      def find_line_matching(pattern)
        @lines.each_with_index do |line, index|
          return index + 1 if line.match?(pattern)
        end
        nil
      end

      def find_all_lines_matching(pattern)
        matches = []
        @lines.each_with_index do |line, index|
          matches << (index + 1) if line.match?(pattern)
        end
        matches
      end

      def find_matching_end(start_line)
        return nil if start_line > @lines.length
        
        do_count = 0
        (@lines.length - start_line + 1).times do |i|
          line_num = start_line + i
          return nil if line_num > @lines.length
          
          line = @lines[line_num - 1]
          
          # Count 'do' keywords
          do_count += line.scan(/\bdo\b/).length
          
          # Count 'end' keywords
          end_count = line.scan(/\bend\b/).length
          do_count -= end_count
          
          # If we've matched all do's with end's, we found the matching end
          if do_count == 0 && end_count > 0
            return line_num
          end
        end
        
        nil
      end

      def extract_line_number(error_message)
        match = error_message.match(/line (\d+)/)
        match ? match[1].to_i : nil
      end
    end
  end
end
