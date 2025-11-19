# frozen_string_literal: true

using NotionForge::Refinements

module NotionForge
  # WorkspaceDriftChecker compares deployed Notion workspace with local definition
  # to detect configuration drift, missing resources, and schema changes
  class WorkspaceDriftChecker
    attr_reader :workspace, :options

    def initialize(workspace, options = {})
      @workspace = workspace
      @options = options
      @results = CheckResults.new
    end

    def check!
      NotionForge.log(:info, "🔍 Starting workspace drift analysis...")
      
      # Load resource IDs from state before checking
      load_resource_ids!
      
      # Check root page
      check_root_page!
      
      # Check databases
      check_databases!
      
      # Check pages
      check_pages!
      
      # Check for extra resources in Notion not in definition
      check_extra_resources! unless options[:ignore_extra]
      
      @results
    end

    private

    def load_resource_ids!
      NotionForge.log(:info, "📋 Loading resource IDs from state...")
      
      # Load IDs for root page
      if workspace.root && NotionForge::StateManager.instance.exists?(workspace.root.state_key)
        workspace.root.instance_variable_set(:@id, NotionForge::StateManager.instance.get_id(workspace.root.state_key))
      end
      
      # Load IDs for databases
      workspace.databases.each do |db|
        if NotionForge::StateManager.instance.exists?(db.state_key)
          db.instance_variable_set(:@id, NotionForge::StateManager.instance.get_id(db.state_key))
        end
      end
      
      # Load IDs for pages
      workspace.pages.each do |page|
        if NotionForge::StateManager.instance.exists?(page.state_key)
          page.instance_variable_set(:@id, NotionForge::StateManager.instance.get_id(page.state_key))
        end
      end
    end

    def check_root_page!
      NotionForge.log(:info, "🏛️ Checking root page...")
      
      root = workspace.root
      
      # Check if root exists
      if root.exists?
        @results.root_status = "✅ Exists"
        
        # Compare root properties
        deployed_root = fetch_deployed_resource(root)
        compare_page_properties(root, deployed_root, @results.root_differences)
      else
        @results.root_status = "❌ Missing"
        @results.add_missing_resource(type: "Page", name: root.title)
      end
    end

    def check_databases!
      NotionForge.log(:info, "📊 Checking databases...")
      
      expected_databases = workspace.databases
      
      expected_databases.each do |db|
        db_details = {
          exists: false,
          schema_differences: [],
          relation_differences: []
        }
        
        if db.exists?
          db_details[:exists] = true
          
          # Fetch deployed database schema
          deployed_db = fetch_deployed_database(db)
          
          # Compare schema
          compare_database_schema(db, deployed_db, db_details[:schema_differences])
          
          # Compare relations
          compare_database_relations(db, deployed_db, db_details[:relation_differences])
          
          @results.add_schema_mismatches(db_details[:schema_differences]) if db_details[:schema_differences].any?
        else
          @results.add_missing_resource(type: "Database", name: db.title)
        end
        
        @results.database_details[db.title] = db_details
      end
      
      @results.database_summary = "#{expected_databases.count} expected, #{@results.missing_resources.count { |r| r[:type] == 'Database' }} missing"
    end

    def check_pages!
      NotionForge.log(:info, "📄 Checking pages...")
      
      expected_pages = workspace.pages
      
      expected_pages.each do |page|
        page_details = {
          exists: false,
          content_differences: []
        }
        
        if page.exists?
          page_details[:exists] = true
          
          unless options[:ignore_content]
            # Fetch deployed page content
            deployed_page = fetch_deployed_resource(page)
            
            # Compare content structure
            compare_page_content(page, deployed_page, page_details[:content_differences])
            
            @results.add_content_differences(page_details[:content_differences]) if page_details[:content_differences].any?
          end
        else
          @results.add_missing_resource(type: "Page", name: page.title)
        end
        
        @results.page_details[page.title] = page_details
      end
      
      @results.page_summary = "#{expected_pages.count} expected, #{@results.missing_resources.count { |r| r[:type] == 'Page' }} missing"
    end

    def check_extra_resources!
      NotionForge.log(:info, "🔍 Checking for extra resources...")
      
      # This would require fetching all children of the root page
      # and comparing with expected resources - more complex operation
      # For now, we'll skip this to avoid making too many API calls
      # TODO: Implement when needed
    end

    def fetch_deployed_resource(resource)
      return nil unless resource.id
      
      begin
        resource.fetch!
        resource.properties
      rescue => e
        NotionForge.log(:warn, "Failed to fetch resource #{resource.id}: #{e.message}")
        nil
      end
    end

    def fetch_deployed_database(database)
      return nil unless database.id
      
      begin
        # Fetch database properties/schema
        response = Client.instance.get("databases/#{database.id}")
        response
      rescue => e
        NotionForge.log(:warn, "Failed to fetch database #{database.id}: #{e.message}")
        nil
      end
    end

    def compare_page_properties(expected, deployed, differences)
      return unless deployed
      
      # Compare title
      expected_title = expected.title
      deployed_title = deployed.dig("properties", "title", "title", 0, "plain_text") || "Untitled"
      
      if expected_title != deployed_title
        differences << {
          property: "title",
          status: :mismatch,
          details: "Expected '#{expected_title}', got '#{deployed_title}'"
        }
      else
        differences << {
          property: "title", 
          status: :ok,
          details: "Matches"
        }
      end
      
      # Compare icon
      expected_icon = expected.icon
      deployed_icon = deployed.dig("icon", "emoji")
      
      if expected_icon != deployed_icon
        differences << {
          property: "icon",
          status: :mismatch, 
          details: "Expected '#{expected_icon}', got '#{deployed_icon}'"
        }
      else
        differences << {
          property: "icon",
          status: :ok,
          details: "Matches"
        }
      end
      
      # Compare cover
      expected_cover = expected.cover
      deployed_cover = deployed.dig("cover", "external", "url") || deployed.dig("cover", "file", "url")
      
      if expected_cover != deployed_cover
        differences << {
          property: "cover",
          status: :mismatch,
          details: "Expected '#{expected_cover}', got '#{deployed_cover}'"
        }
      else
        differences << {
          property: "cover",
          status: :ok, 
          details: "Matches"
        }
      end
    end

    def compare_database_schema(expected, deployed, differences)
      return unless deployed
      
      expected_schema = expected.schema || {}
      deployed_properties = deployed.dig("properties") || {}
      
      # Check each expected property
      expected_schema.each do |prop_name, prop_config|
        deployed_prop = deployed_properties[prop_name]
        
        if deployed_prop.nil?
          differences << {
            property: prop_name,
            issue: "Missing property"
          }
        else
          # Compare property type
          expected_type = prop_config[:type]
          deployed_type = deployed_prop["type"]
          
          if expected_type != deployed_type
            differences << {
              property: prop_name,
              issue: "Type mismatch: expected #{expected_type}, got #{deployed_type}"
            }
          end
          
          # Compare property configuration (options for select/status, etc.)
          if prop_config[:options] && deployed_prop[deployed_type]
            compare_property_options(prop_name, prop_config, deployed_prop, differences)
          end
        end
      end
      
      # Check for extra properties in deployed database
      deployed_properties.each do |prop_name, _|
        unless expected_schema.key?(prop_name) || prop_name == "title" # title is implicit
          differences << {
            property: prop_name,
            issue: "Extra property not in definition"
          }
        end
      end
    end

    def compare_property_options(prop_name, expected_config, deployed_prop, differences)
      expected_options = expected_config[:options] || []
      deployed_options = deployed_prop.dig(deployed_prop["type"], "options") || []
      
      # Convert to comparable format
      expected_names = expected_options.map { |opt| opt.is_a?(Hash) ? opt[:name] : opt.to_s }
      deployed_names = deployed_options.map { |opt| opt["name"] }
      
      missing_options = expected_names - deployed_names
      extra_options = deployed_names - expected_names
      
      if missing_options.any?
        differences << {
          property: prop_name,
          issue: "Missing options: #{missing_options.join(', ')}"
        }
      end
      
      if extra_options.any?
        differences << {
          property: prop_name,
          issue: "Extra options: #{extra_options.join(', ')}"
        }
      end
    end

    def compare_database_relations(expected, deployed, differences)
      return unless deployed
      
      expected_relations = expected.relations || {}
      deployed_properties = deployed.dig("properties") || {}
      
      expected_relations.each do |relation_name, relation_config|
        deployed_prop = deployed_properties[relation_name]
        
        if deployed_prop.nil?
          differences << {
            relation: relation_name,
            issue: "Missing relation"
          }
        elsif deployed_prop["type"] != "relation"
          differences << {
            relation: relation_name,
            issue: "Property exists but is not a relation"
          }
        else
          # Could compare target database IDs here if needed
          # For now, just check existence
        end
      end
    end

    def compare_page_content(expected, deployed, differences)
      return unless deployed
      
      # For content comparison, we'd need to analyze the page's children
      # This is complex as it involves comparing block structures
      # For now, we'll do a simple comparison
      
      expected_children = expected.children || []
      
      if expected_children.any?
        # Fetch actual page content
        begin
          content_response = Client.instance.get("blocks/#{expected.id}/children")
          deployed_blocks = content_response["results"] || []
          
          # Simple comparison - count blocks by type
          expected_block_types = expected_children.map { |block| block[:type] || block.type rescue :unknown }.tally
          deployed_block_types = deployed_blocks.map { |block| block["type"] }.tally
          
          expected_block_types.each do |type, count|
            deployed_count = deployed_block_types[type.to_s] || 0
            if deployed_count != count
              differences << {
                section: "Content blocks",
                change: "#{type}: expected #{count}, got #{deployed_count}"
              }
            end
          end
        rescue => e
          differences << {
            section: "Content analysis",
            change: "Could not analyze content: #{e.message}"
          }
        end
      end
    end
  end

  # Results container for drift checking
  class CheckResults
    attr_accessor :root_status, :database_summary, :page_summary
    attr_reader :missing_resources, :extra_resources, :schema_mismatches, 
                :content_differences, :root_differences, :database_details, :page_details

    def initialize
      @root_status = "Unknown"
      @database_summary = "Unknown"
      @page_summary = "Unknown" 
      @missing_resources = []
      @extra_resources = []
      @schema_mismatches = []
      @content_differences = []
      @root_differences = []
      @database_details = {}
      @page_details = {}
    end

    def add_missing_resource(type:, name:)
      @missing_resources << { type: type, name: name }
    end

    def add_extra_resource(type:, name:)
      @extra_resources << { type: type, name: name }
    end

    def add_schema_mismatches(mismatches)
      @schema_mismatches.concat(mismatches.map { |m| { database: "Database", issue: "#{m[:property]}: #{m[:issue]}" } })
    end

    def add_content_differences(differences)
      @content_differences.concat(differences.map { |d| { resource: "Page", change: "#{d[:section]}: #{d[:change]}" } })
    end

    def has_issues?
      total_issues > 0
    end

    def total_issues
      @missing_resources.size + @extra_resources.size + @schema_mismatches.size + @content_differences.size
    end

    def to_h
      {
        summary: {
          root_status: @root_status,
          database_summary: @database_summary,
          page_summary: @page_summary,
          total_issues: total_issues,
          has_issues: has_issues?
        },
        issues: {
          missing_resources: @missing_resources,
          extra_resources: @extra_resources,
          schema_mismatches: @schema_mismatches,
          content_differences: @content_differences
        },
        details: {
          root_differences: @root_differences,
          database_details: @database_details,
          page_details: @page_details
        }
      }
    end
  end
end
