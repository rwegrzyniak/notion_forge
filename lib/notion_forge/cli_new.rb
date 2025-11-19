# frozen_string_literal: true

require "thor"
require "yaml"
require "fileutils"
require "json"
require "openssl"
require "io/console"
require "base64"
require "digest"

module NotionForge
  class CLI < Thor
    include Thor::Actions

    def self.exit_on_failure?
      true
    end

    class_option :verbose, aliases: ["-v"], type: :boolean, default: false, desc: "Enable verbose output"
    class_option :config, aliases: ["-c"], type: :string, desc: "Config file path", default: "notionforge.yml"

    # Setup command for initial configuration
    desc "setup", "Set up NotionForge with your Notion API credentials"
    long_desc <<~DESC
      Interactive setup to configure NotionForge with your Notion API token and parent page ID.
      Your credentials will be encrypted and stored securely in #{File.expand_path("~/.notion_forge")}.

      You'll need:
      1. Notion API Integration Token (from https://developers.notion.com)
      2. Parent Page ID (where workspaces will be created)
    DESC
    option :force, type: :boolean, desc: "Force reconfiguration"
    def setup
      say "🔧 NotionForge Setup", :bold
      say "━" * 50
      
      # Check if already configured
      if config_exists? && !options[:force]
        if yes?("Configuration already exists. Reconfigure? [y/N]")
          say "Reconfiguring...", :yellow
        else
          say "Setup cancelled.", :red
          exit 0
        end
      end

      # Collect Notion API token
      say "\n📋 Step 1: Notion API Integration"
      say "Visit: https://developers.notion.com/my-integrations"
      say "Create a new integration and copy the token."
      
      token = ask("Enter your Notion API token:", echo: false) do |q|
        q.validate = /^secret_[a-zA-Z0-9]{43}$/
        q.responses[:not_valid] = "❌ Invalid token format. Should start with 'secret_' followed by 43 characters."
      end

      # Validate token by making a test request
      say "\n🔍 Validating token...", :yellow
      if validate_token(token)
        say "✅ Token validated successfully!", :green
      else
        say "❌ Invalid token or connection failed. Please check and try again.", :red
        exit 1
      end

      # Collect parent page ID
      say "\n📄 Step 2: Parent Page Configuration"
      say "This is where your NotionForge workspaces will be created."
      say "Share a Notion page with your integration and copy its ID from the URL."
      say "Example: https://notion.so/workspace/PAGE_ID?v=... → copy PAGE_ID"
      
      parent_page_id = ask("Enter parent page ID:") do |q|
        q.validate = /^[a-f0-9]{8}-?[a-f0-9]{4}-?[a-f0-9]{4}-?[a-f0-9]{4}-?[a-f0-9]{12}$/i
        q.responses[:not_valid] = "❌ Invalid page ID format. Should be a UUID."
      end

      # Validate page access
      say "\n🔍 Validating page access...", :yellow
      if validate_page_access(token, parent_page_id)
        say "✅ Page access validated!", :green
      else
        say "❌ Cannot access page. Please check the page ID and integration permissions.", :red
        exit 1
      end

      # Save encrypted configuration
      say "\n💾 Saving configuration...", :yellow
      save_encrypted_config(token, parent_page_id)
      say "✅ Configuration saved securely!", :green

      # Success message
      say "\n🎉 Setup Complete!", :bold, :green
      say "━" * 50
      say "NotionForge is ready to use!"
      say ""
      say "Try these commands:"
      say "  notion_forge examples          # Generate example workspaces"
      say "  notion_forge forge <file.rb>   # Deploy a workspace"
      say "  notion_forge validate <file>   # Validate workspace syntax"
    end

    desc "status", "Show current configuration status"
    def status
      say "📊 NotionForge Status", :bold
      say "━" * 50

      if config_exists?
        config = load_encrypted_config
        say "✅ Configuration found", :green
        say "   Token: secret_***#{config['token'][-8..]}" if config['token']
        say "   Parent Page: #{config['parent_page_id'][0..7]}...#{config['parent_page_id'][-8..]}" if config['parent_page_id']
        say "   Config file: #{config_path}"
        
        # Test connection
        say "\n🔍 Testing connection...", :yellow
        if validate_token(config['token'])
          say "✅ API connection successful", :green
        else
          say "❌ API connection failed", :red
        end
      else
        say "❌ Not configured", :red
        say "Run: notion_forge setup"
      end
    end

    desc "version", "Show NotionForge version"
    def version
      puts "NotionForge v#{NotionForge::VERSION}"
    end

    desc "forge [WORKSPACE_FILE]", "Create/update Notion workspace from Ruby file"
    method_option :mode, aliases: ["-m"], type: :string, default: "update", 
                  enum: ["fresh", "update", "force"], 
                  desc: "Forge mode: fresh (only if not exists), update (idempotent), force (recreate)"
    method_option :rate_limit, aliases: ["-r"], type: :numeric, default: 0.5, 
                  desc: "Delay between API requests (seconds) for rate limiting"
    def forge(workspace_file = nil)
      load_config_for_forge
      
      workspace_file ||= find_workspace_file
      return say_error("No workspace file found!") unless workspace_file
      return say_error("Workspace file not found: #{workspace_file}") unless File.exist?(workspace_file)

      say("🔥 Loading workspace from: #{workspace_file}", :yellow)
      say("🛡️ Using safe sequential processing with rate limiting", :blue)
      
      begin
        load workspace_file
        
        if defined?(forge_workspace)
          workspace = forge_workspace
          workspace.forge!(mode: options[:mode].to_sym)
        elsif defined?(WORKSPACE)
          WORKSPACE.forge!(mode: options[:mode].to_sym)
        else
          say_error("No workspace defined! Expected 'forge_workspace' method or WORKSPACE constant")
        end
      rescue NotionForge::Error => e
        say_error("NotionForge Error: #{e.message}")
        exit 1
      rescue StandardError => e
        say_error("Error: #{e.message}")
        say("Backtrace:", :red) if options[:verbose]
        say(e.backtrace.join("\n"), :red) if options[:verbose]
        exit 1
      end
    end

    desc "validate [WORKSPACE_FILE]", "Validate workspace file syntax"
    def validate(workspace_file = nil)
      workspace_file ||= find_workspace_file
      return say_error("No workspace file found!") unless workspace_file
      return say_error("Workspace file not found: #{workspace_file}") unless File.exist?(workspace_file)

      say("🔍 Validating workspace file: #{workspace_file}", :yellow)
      
      begin
        load workspace_file
        say("✅ Syntax is valid!", :green)
      rescue SyntaxError => e
        say_error("Syntax Error: #{e.message}")
        exit 1
      rescue StandardError => e
        say_error("Error: #{e.message}")
        exit 1
      end
    end

    desc "visualize [WORKSPACE_FILE]", "Generate ASCII art visualization of workspace structure"
    option :style, type: :string, default: "tree", enum: ["tree", "box", "graph"], 
           desc: "Visualization style: tree, box, or graph"
    option :depth, type: :numeric, default: 3, desc: "Maximum depth to visualize"
    option :show_properties, type: :boolean, default: false, desc: "Show database properties"
    option :show_relations, type: :boolean, default: true, desc: "Show database relations"
    option :compact, type: :boolean, default: false, desc: "Use compact layout"
    def visualize(workspace_file = nil)
      workspace_file ||= find_workspace_file
      return say_error("No workspace file found!") unless workspace_file
      return say_error("Workspace file not found: #{workspace_file}") unless File.exist?(workspace_file)

      say("🎨 Visualizing workspace: #{workspace_file}", :yellow)
      say("━" * 60)
      
      begin
        # Load workspace without API calls
        workspace = load_workspace_for_visualization(workspace_file)
        
        case options[:style]
        when "tree"
          render_tree_visualization(workspace)
        when "box" 
          render_box_visualization(workspace)
        when "graph"
          render_graph_visualization(workspace)
        end
        
        render_statistics(workspace)
        
      rescue StandardError => e
        say_error("Visualization failed: #{e.message}")
        say("Run with --verbose for more details", :yellow) unless options[:verbose]
        say(e.backtrace.join("\n"), :red) if options[:verbose]
        exit 1
      end
    end

    desc "examples", "Generate example workspace files"
    method_option :type, aliases: ["-t"], type: :string, default: "all", 
                  enum: ["all", "demo", "philosophical"], 
                  desc: "Type of example to generate"
    def examples
      say("📚 Creating example workspace files...", :yellow)
      
      case options[:type]
      when "all"
        create_demo_example
        create_philosophical_example
      when "demo"
        create_demo_example
      when "philosophical"
        create_philosophical_example
      end
      
      say("\n🎉 Examples created! Try:", :green)
      say("  notion_forge visualize demo_workspace.rb")
      say("  notion_forge forge demo_workspace.rb")
    end

    private

    # Configuration management
    def config_path
      File.expand_path("~/.notion_forge")
    end

    def config_exists?
      File.exist?(config_path)
    end

    def encryption_key
      # Use a machine-specific key for basic security
      machine_id = `uname -n`.strip rescue "unknown"
      user_id = ENV['USER'] || ENV['USERNAME'] || "unknown"
      Digest::SHA256.digest("#{machine_id}:#{user_id}:notion_forge")
    end

    def save_encrypted_config(token, parent_page_id)
      config = {
        'token' => token,
        'parent_page_id' => parent_page_id,
        'created_at' => Time.now.iso8601,
        'version' => NotionForge::VERSION
      }

      # Encrypt the configuration
      cipher = OpenSSL::Cipher.new('AES-256-GCM')
      cipher.encrypt
      cipher.key = encryption_key
      iv = cipher.random_iv
      
      encrypted_data = cipher.update(JSON.generate(config)) + cipher.final
      auth_tag = cipher.auth_tag

      # Save encrypted data with IV and auth tag
      encrypted_config = {
        'iv' => Base64.strict_encode64(iv),
        'auth_tag' => Base64.strict_encode64(auth_tag),
        'data' => Base64.strict_encode64(encrypted_data)
      }

      File.write(config_path, JSON.generate(encrypted_config))
      File.chmod(0600, config_path) # Readable only by owner
    end

    def load_encrypted_config
      return nil unless config_exists?

      encrypted_config = JSON.parse(File.read(config_path))
      
      # Decrypt the configuration
      cipher = OpenSSL::Cipher.new('AES-256-GCM')
      cipher.decrypt
      cipher.key = encryption_key
      cipher.iv = Base64.strict_decode64(encrypted_config['iv'])
      cipher.auth_tag = Base64.strict_decode64(encrypted_config['auth_tag'])
      
      decrypted_data = cipher.update(Base64.strict_decode64(encrypted_config['data'])) + cipher.final
      JSON.parse(decrypted_data)
    rescue => e
      say "❌ Failed to decrypt configuration: #{e.message}", :red
      say "Run 'notion_forge setup --force' to reconfigure", :yellow
      exit 1
    end

    def validate_token(token)
      # Make a simple API call to validate the token
      require 'net/http'
      require 'uri'
      
      uri = URI('https://api.notion.com/v1/users/me')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{token}"
      request['Notion-Version'] = '2022-06-28'
      
      response = http.request(request)
      response.code == '200'
    rescue
      false
    end

    def validate_page_access(token, page_id)
      # Try to retrieve the page to validate access
      require 'net/http'
      require 'uri'
      
      # Clean up page ID (remove hyphens and normalize)
      clean_page_id = page_id.gsub('-', '')
      
      uri = URI("https://api.notion.com/v1/pages/#{clean_page_id}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{token}"
      request['Notion-Version'] = '2022-06-28'
      
      response = http.request(request)
      response.code == '200'
    rescue
      false
    end

    def ensure_configured!
      unless config_exists?
        say "❌ NotionForge is not configured.", :red
        say "Run: notion_forge setup", :yellow
        exit 1
      end
    end

    def load_config_for_forge
      ensure_configured!
      config = load_encrypted_config
      
      NotionForge.configure do |c|
        c.token = config['token']
        c.parent_page_id = config['parent_page_id']
        c.verbose = options[:verbose]
      end
    end

    # Visualization helpers
    def load_workspace_for_visualization(workspace_file)
      # Mock configuration to avoid API calls
      NotionForge.configure do |c|
        c.token = "mock_token"
        c.parent_page_id = "mock_page_id"
        c.verbose = false
      end
      
      load workspace_file
      
      if defined?(forge_workspace)
        forge_workspace
      elsif defined?(WORKSPACE)
        WORKSPACE
      else
        raise "No workspace defined! Expected 'forge_workspace' method or WORKSPACE constant"
      end
    end

    def render_tree_visualization(workspace)
      say("🏛️  #{workspace.root.title}", :bold, :blue)
      say("#{workspace.root.icon} #{workspace.root.cover ? '🖼️ ' : ''}")
      say("")
      
      # Render databases
      if workspace.databases.any?
        say("📊 Databases:", :bold, :green)
        workspace.databases.each_with_index do |db, index|
          is_last_db = index == workspace.databases.size - 1
          prefix = is_last_db ? "└── " : "├── "
          
          say("#{prefix}#{db.icon || '📊'} #{db.title}", :green)
          
          if options[:show_properties] && db.schema.any?
            property_prefix = is_last_db ? "    " : "│   "
            db.schema.each_with_index do |(name, _), prop_index|
              is_last_prop = prop_index == db.schema.size - 1
              prop_connector = is_last_prop ? "└── " : "├── "
              say("#{property_prefix}#{prop_connector}🏷️  #{name}", :cyan)
            end
          end
          
          if options[:show_relations] && db.relations.any?
            relation_prefix = is_last_db ? "    " : "│   "
            db.relations.each_with_index do |(name, config), rel_index|
              is_last_rel = rel_index == db.relations.size - 1
              rel_connector = is_last_rel ? "└── " : "├── "
              target_title = config[:target].respond_to?(:title) ? config[:target].title : "Unknown"
              say("#{relation_prefix}#{rel_connector}🔗 #{name} → #{target_title}", :magenta)
            end
          end
        end
        say("")
      end
      
      # Render pages
      if workspace.pages.any?
        say("📄 Pages:", :bold, :yellow)
        workspace.pages.each_with_index do |page, index|
          is_last = index == workspace.pages.size - 1
          prefix = is_last ? "└── " : "├── "
          
          content_info = options[:compact] ? "" : " (#{page.children.size} blocks)"
          say("#{prefix}#{page.icon || '📄'} #{page.title}#{content_info}", :yellow)
        end
        say("")
      end
    end

    def render_statistics(workspace)
      say("📈 Workspace Statistics", :bold, :white)
      say("─" * 25)
      
      total_properties = workspace.databases.sum { |db| db.schema.size }
      total_relations = workspace.databases.sum { |db| db.relations.size }
      total_blocks = workspace.pages.sum { |page| page.children.size }
      
      stats = [
        ["📊 Databases", workspace.databases.size],
        ["📄 Pages", workspace.pages.size], 
        ["🏷️  Properties", total_properties],
        ["🔗 Relations", total_relations],
        ["🧱 Content Blocks", total_blocks],
        ["📏 Total Resources", workspace.resources.size]
      ]
      
      stats.each do |label, count|
        say("#{label.ljust(18)} #{count.to_s.rjust(6)}", count > 0 ? :green : :red)
      end
      
      say("")
      
      # Complexity indicators
      complexity_score = calculate_complexity_score(workspace)
      complexity_color = case complexity_score
                        when 0..10 then :green
                        when 11..25 then :yellow
                        else :red
                        end
      
      say("🎯 Complexity Score: #{complexity_score}/100", :bold, complexity_color)
      say("   #{complexity_description(complexity_score)}", complexity_color)
    end

    def calculate_complexity_score(workspace)
      # Simple complexity calculation
      db_complexity = workspace.databases.size * 5
      page_complexity = workspace.pages.size * 2
      property_complexity = workspace.databases.sum { |db| db.schema.size }
      relation_complexity = workspace.databases.sum { |db| db.relations.size } * 3
      
      [db_complexity + page_complexity + property_complexity + relation_complexity, 100].min
    end

    def complexity_description(score)
      case score
      when 0..10
        "Simple workspace - easy to maintain"
      when 11..25
        "Moderate complexity - well structured"
      when 26..50
        "Complex workspace - consider organization"
      else
        "Very complex - may need refactoring"
      end
    end

    # Helper methods for file detection and examples
    def find_workspace_file
      # Look for workspace files in current directory
      candidates = Dir.glob("*workspace*.rb") + Dir.glob("*_workspace.rb") + Dir.glob("workspace*.rb")
      candidates.first
    end

    def create_demo_example
      # Basic demo example
      say("📝 Creating demo workspace example...", :blue)
      say("✅ Use existing demo_workspace.rb", :green) if File.exist?("demo_workspace.rb")
    end

    def create_philosophical_example
      # Use existing philosophical workspace
      say("📝 Creating philosophical workspace example...", :blue)
      say("✅ Use existing philosophical_workspace.rb", :green) if File.exist?("philosophical_workspace.rb")
    end

    def say_error(message)
      say("❌ #{message}", :red)
    end
  end
end
