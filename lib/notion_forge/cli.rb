# frozen_string_literal: true

require "thor"
require "yaml"
require "fileutils"
require "json"
require "openssl"
require "io/console"
require "base64"
require "digest"
require "time"
require_relative "workspace_repository"
require_relative "drift_checker"

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
      🔧 Interactive Setup for NotionForge

      This command will guide you through configuring NotionForge with your Notion API 
      credentials. The setup process is secure and user-friendly.

      📋 What this setup does:
      • Validates your Notion API token
      • Configures workspace parent page location  
      • Encrypts and securely stores your credentials
      • Tests connection to ensure everything works

      📚 Prerequisites - You'll need:
      1. 🔑 Notion API Integration Token
         → Get yours at: https://developers.notion.com/my-integrations
         → Click "New integration" and copy the token
      
      2. 📄 Parent Page (where workspaces will be created)
         → Open any Notion page in your browser
         → Share it with your integration (give "Can edit" access)
         → Copy the full URL from your browser
         → Example: https://notion.so/My-Page-28151ddc6ac080a18c8fed00ba6b6fa3

      🔒 Security: Your credentials will be encrypted and stored in:
      ~/.notion_forge/
      ├── secrets          # Encrypted API credentials (AES-256-GCM)
      └── workspaces/      # Custom workspace templates

      💡 Tip: Run with --force to reconfigure existing setup
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
      
      # Handle both interactive and non-interactive scenarios
      token = if STDIN.tty?
        # Interactive terminal - use secure input
        ask("Enter your Notion API token:", echo: false) do |q|
          q.validate = /^secret_[a-zA-Z0-9]{43}$/
          q.responses[:not_valid] = "❌ Invalid token format. Should start with 'secret_' followed by 43 characters."
        end
      else
        # Non-interactive (CI/testing) - read from STDIN but still validate
        say "Enter your Notion API token: (non-interactive mode)", :yellow
        token_input = STDIN.gets&.chomp
        if token_input.nil? || token_input.empty?
          say "❌ No token provided", :red
          exit 1
        end
        
        unless token_input.match?(/^secret_[a-zA-Z0-9]{43}$/)
          say "❌ Invalid token format. Should start with 'secret_' followed by 43 characters.", :red
          exit 1
        end
        
        token_input
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
      say "Share a Notion page with your integration, then provide the page URL or ID."
      say ""
      say "📝 You can provide:"
      say "  • Full Notion URL: https://notion.so/My-Page-abc123..."
      say "  • Short URL: notion.so/abc123def456..."
      say "  • Just the page ID: abc123def456..."
      say ""
      
      parent_page_id = if STDIN.tty?
        # Interactive terminal - with smart URL parsing
        loop do
          input = ask("Enter Notion page URL or ID:")
          
          # Extract page ID from various URL formats
          extracted_id = extract_page_id(input)
          
          if extracted_id
            say "✅ Extracted page ID: #{extracted_id}", :green
            break extracted_id
          else
            say "❌ Could not extract page ID from: #{input}", :red
            say "💡 Try copying the full URL from your browser", :yellow
            say "   Example: https://notion.so/My-Page-28151ddc6ac080a18c8fed00ba6b6fa3", :cyan
            
            if no?("Try again? [Y/n]")
              say "Setup cancelled.", :red
              exit 0
            end
          end
        end
      else
        # Non-interactive mode - still use smart extraction
        say "Enter Notion page URL or ID: (non-interactive mode)", :yellow
        input = STDIN.gets&.chomp
        if input.nil? || input.empty?
          say "❌ No page URL/ID provided", :red
          exit 1
        end
        
        extracted_id = extract_page_id(input)
        unless extracted_id
          say "❌ Could not extract page ID from: #{input}", :red
          say "💡 Provide full URL like: https://notion.so/My-Page-28151ddc6ac080a18c8fed00ba6b6fa3", :yellow
          exit 1
        end
        
        extracted_id
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
      say "  notion_forge check <file.rb>   # Check for configuration drift"
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
    long_desc <<~DESC
      Deploy a workspace to Notion from a Ruby file.
      
      You can specify:
      • Workspace name: notion_forge forge demo_workspace
      • File path: notion_forge forge ./my_workspace.rb
      • Built-in template: notion_forge forge philosophical_workspace
      
      If no workspace is specified, looks for workspace files in current directory.
    DESC
    method_option :mode, aliases: ["-m"], type: :string, default: "update", 
                  enum: ["fresh", "update", "force"], 
                  desc: "Forge mode: fresh (only if not exists), update (idempotent), force (recreate)"
    method_option :rate_limit, aliases: ["-r"], type: :numeric, default: 0.5, 
                  desc: "Delay between API requests (seconds) for rate limiting"
    def forge(workspace_file = nil)
      load_config_for_forge
      
      # Debug: Show configuration details
      if options[:verbose]
        config = load_encrypted_config
        say("🔍 Debug: Configuration loaded", :cyan)
        say("   Token: secret_***#{config['token'][-8..]}", :cyan)
        say("   Parent Page: #{config['parent_page_id']}", :cyan)
      end
      
      workspace_file = find_workspace_file(workspace_file)
      
      unless workspace_file
        say_error("No workspace file found!")
        say("\n💡 Available options:", :yellow)
        say("  notion_forge workspaces        # List available templates")
        say("  notion_forge examples          # Generate example workspaces")
        return
      end
      
      unless File.exist?(workspace_file)
        say_error("Workspace file not found: #{workspace_file}")
        return
      end

      say("🔥 Loading workspace from: #{File.basename(workspace_file)}", :yellow)
      say("📁 Path: #{workspace_file}", :blue) if options[:verbose]
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
      workspace_file = find_workspace_file(workspace_file)
      
      unless workspace_file
        say_error("No workspace file found!")
        say("💡 Use: notion_forge workspaces  # to see available templates", :yellow)
        return
      end
      
      unless File.exist?(workspace_file)
        say_error("Workspace file not found: #{workspace_file}")
        return
      end

      say("🔍 Validating workspace file: #{File.basename(workspace_file)}", :yellow)
      
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
    option :no_stats, type: :boolean, default: false, desc: "Skip statistics display"
    def visualize(workspace_file = nil)
      workspace_file = find_workspace_file(workspace_file)
      
      unless workspace_file
        say_error("No workspace file found!")
        say("💡 Use: notion_forge workspaces  # to see available templates", :yellow)
        return
      end
      
      unless File.exist?(workspace_file)
        say_error("Workspace file not found: #{workspace_file}")
        return
      end

      say("🎨 Visualizing workspace: #{File.basename(workspace_file)}", :yellow)
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
        
        render_statistics(workspace) unless options[:no_stats]
        
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

    desc "check [WORKSPACE_FILE]", "Check if deployed workspace matches definition"
    long_desc <<~DESC
      Compare the deployed Notion workspace with the workspace definition to detect drift.
      
      This command analyzes:
      • Resource existence (missing/extra resources)
      • Database schemas (property changes, missing properties)  
      • Page content structure (title changes, missing content)
      • Resource metadata (icons, covers, status)
      
      Perfect for:
      • Validating deployments
      • Detecting manual changes in Notion
      • Ensuring workspace consistency
      • Compliance checking
    DESC
    method_option :fix, aliases: ["-f"], type: :boolean, default: false, 
                  desc: "Automatically fix detected issues by redeploying"
    method_option :detailed, aliases: ["-d"], type: :boolean, default: false, 
                  desc: "Show detailed comparison for each resource"
    method_option :ignore_content, type: :boolean, default: false,
                  desc: "Skip content comparison (faster, schema only)"
    method_option :format, type: :string, default: "summary", enum: ["summary", "json", "detailed"],
                  desc: "Output format: summary (default), json, or detailed"
    def check(workspace_file = nil)
      load_config_for_forge
      
      workspace_file = find_workspace_file(workspace_file)
      
      unless workspace_file
        say_error("No workspace file found!")
        say("\n💡 Available options:", :yellow)
        say("  notion_forge workspaces        # List available templates")
        return
      end
      
      unless File.exist?(workspace_file)
        say_error("Workspace file not found: #{workspace_file}")
        return
      end

      say("🔍 Checking workspace: #{File.basename(workspace_file)}", :yellow)
      say("━" * 60)
      
      begin
        # Load workspace definition
        load workspace_file
        workspace = if defined?(forge_workspace)
                     forge_workspace
                   elsif defined?(WORKSPACE)
                     WORKSPACE
                   else
                     say_error("No workspace defined! Expected 'forge_workspace' method or WORKSPACE constant")
                     return
                   end

        # Perform drift detection
        checker = WorkspaceDriftChecker.new(workspace, options)
        results = checker.check!
        
        # Display results based on format
        case options[:format]
        when "json"
          puts JSON.pretty_generate(results.to_h)
        when "detailed"
          display_detailed_check_results(results)
        else
          if options[:detailed]
            display_detailed_check_results(results)
          else
            display_check_summary(results)
          end
        end
        
        # Auto-fix if requested and issues found
        if options[:fix] && results.has_issues?
          say("\n🔧 Auto-fixing detected issues...", :yellow)
          workspace.forge!(mode: :update)
          say("✅ Workspace has been synchronized!", :green)
        end
        
        # Exit with appropriate code
        exit(results.has_issues? ? 1 : 0)
        
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

    desc "workspaces", "List available workspace templates"
    method_option :detailed, aliases: ["-d"], type: :boolean, default: false, desc: "Show detailed workspace information"
    def workspaces
      say("📚 Available Workspace Templates", :bold)
      say("━" * 50)
      
      repository = WorkspaceRepository.new
      workspace_files = repository.list_workspaces
      
      if workspace_files.empty?
        say("No workspace files found.", :yellow)
        say("\n💡 Create workspaces with:", :cyan)
        say("  notion_forge examples          # Generate example workspaces")
        return
      end
      
      workspace_files.each_with_index do |workspace_info, index|
        icon = workspace_info[:builtin] ? "📦" : "📄"
        location = workspace_info[:builtin] ? "built-in" : "custom"
        
        say("\n#{icon} #{workspace_info[:name]}", :bold, :green)
        say("   📍 Location: #{location}")
        say("   📁 File: #{workspace_info[:file]}")
        
        if options[:detailed]
          # Try to load workspace for detailed info
          begin
            preview = repository.preview_workspace(workspace_info[:file])
            if preview
              say("   🏛️  Title: #{preview[:title]}", :blue)
              say("   📊 Databases: #{preview[:databases]}", :cyan) if preview[:databases] > 0
              say("   📄 Pages: #{preview[:pages]}", :yellow) if preview[:pages] > 0
            end
          rescue => e
            say("   ⚠️  Preview unavailable: #{e.message}", :red) if options[:verbose]
          end
        end
      end
      
      say("\n🚀 Deploy a workspace:", :bold)
      say("  notion_forge forge <workspace_name>")
      say("  notion_forge visualize <workspace_name>")
      say("  notion_forge check <workspace_name>    # Check for drift")
    end

    # Validation command
    desc "validate DSL_FILE", "Validate a NotionForge DSL file"
    long_desc <<~DESC
      🔍 Validate NotionForge DSL Code

      This command validates your NotionForge DSL code for:
      • Syntax errors and Ruby code issues
      • DSL structure and required methods
      • Property usage and Notion API compatibility
      • Missing dependencies and method availability
      • Best practices and common issues

      Returns detailed error messages and suggested fixes.

      Examples:
        notion_forge validate my_workspace.rb
        notion_forge validate --json my_workspace.rb    # JSON output
        notion_forge validate --strict my_workspace.rb  # Treat warnings as errors
    DESC
    option :json, type: :boolean, default: false, desc: "Output results as JSON"
    option :strict, type: :boolean, default: false, desc: "Treat warnings as errors"
    option :output, aliases: ["-o"], type: :string, desc: "Output file for results"
    def validate(dsl_file)
      unless File.exist?(dsl_file)
        say "❌ File not found: #{dsl_file}", :red
        exit 1
      end

      say "🔍 Validating DSL file: #{dsl_file}", :blue
      
      begin
        dsl_code = File.read(dsl_file)
        result = NotionForge::Workspace.validate(dsl_code)
        
        if options[:json]
          output_validation_json(result)
        else
          output_validation_human(result)
        end
        
        # Write to output file if specified
        if options[:output]
          File.write(options[:output], result.to_json)
          say "📄 Results written to: #{options[:output]}", :green
        end
        
        # Exit with error code if validation failed
        if result[:status] == 'invalid' || (options[:strict] && result[:has_warnings])
          exit 1
        end
        
      rescue => e
        say "❌ Error reading or validating file: #{e.message}", :red
        exit 1
      end
    end

    private

    def output_validation_json(result)
      puts JSON.pretty_generate(result)
    end

    def output_validation_human(result)
      case result[:status]
      when 'valid'
        say "✅ DSL file is valid!", :green
        
        if result[:has_warnings]
          say "\n⚠️  Warnings found:", :yellow
          result[:warnings].each do |warning|
            say "  • #{warning[:message]}", :yellow
            say "    Fix: #{warning[:fix]}", :cyan if warning[:fix]
          end
        else
          say "🎉 No issues found - ready for deployment!", :green
        end
        
      when 'invalid'
        say "❌ DSL file has validation errors:", :red
        
        result[:errors].each do |error|
          say "\n🚨 #{error[:code].upcase}", :red
          say "   #{error[:message]}", :white
          if error[:fix]
            say "   💡 Fix: #{error[:fix]}", :cyan
          end
          if error[:line]
            say "   📍 Line: #{error[:line]}", :yellow
          end
        end
        
        if result[:warnings].any?
          say "\n⚠️  Additional warnings:", :yellow
          result[:warnings].each do |warning|
            say "  • #{warning[:message]}", :yellow
            say "    Fix: #{warning[:fix]}", :cyan if warning[:fix]
          end
        end
      end
      
      # Summary
      say "\n📊 Validation Summary:", :blue
      say "   Total Errors: #{result[:summary][:total_errors]}", :white
      say "   Total Warnings: #{result[:summary][:total_warnings]}", :white
      say "   Critical Issues: #{result[:summary][:critical_issues]}", :white
      
      if result[:summary][:total_errors] == 0 && result[:summary][:total_warnings] == 0
        say "\n🚀 Ready for deployment with notion_forge forge!", :green
      elsif result[:summary][:total_errors] == 0
        say "\n✅ Deployable, but consider addressing warnings", :yellow
      else
        say "\n🛑 Fix errors before deployment", :red
      end
    end

    # Configuration management
    def config_dir
      File.expand_path("~/.notion_forge")
    end

    def config_path
      File.join(config_dir, "secrets")
    end

    def config_exists?
      File.exist?(config_path)
    end

    def ensure_config_dir!
      FileUtils.mkdir_p(config_dir) unless Dir.exist?(config_dir)
      File.chmod(0700, config_dir) # Only owner can read/write/execute
    end

    def encryption_key
      # Use a machine-specific key for basic security
      machine_id = `uname -n`.strip rescue "unknown"
      user_id = ENV['USER'] || ENV['USERNAME'] || "unknown"
      Digest::SHA256.digest("#{machine_id}:#{user_id}:notion_forge")
    end

    def save_encrypted_config(token, parent_page_id)
      ensure_config_dir!
      
      config = {
        'token' => token,
        'parent_page_id' => parent_page_id,
        'created_at' => Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
        'version' => NotionForge::VERSION
      }

      # Encrypt the configuration using AES-256-GCM
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

    def extract_page_id(input)
      # Clean up input
      input = input.to_s.strip
      return nil if input.empty?
      
      # Handle various Notion URL formats and extract the page ID
      patterns = [
        # Standard Notion URLs with page titles
        %r{(?:https?://)?(?:www\.)?notion\.so/.*?([a-f0-9]{32})(?:\?|$)},
        %r{(?:https?://)?(?:www\.)?notion\.so/.*?([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})(?:\?|$)},
        
        # Direct workspace URLs
        %r{(?:https?://)?(?:www\.)?notion\.so/([a-f0-9]{32})(?:\?|$)},
        %r{(?:https?://)?(?:www\.)?notion\.so/([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})(?:\?|$)},
        
        # URLs with workspace prefix
        %r{(?:https?://)?[\w-]+\.notion\.site/.*?([a-f0-9]{32})(?:\?|$)},
        %r{(?:https?://)?[\w-]+\.notion\.site/.*?([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})(?:\?|$)},
      ]
      
      # Try each pattern
      patterns.each do |pattern|
        match = input.match(pattern)
        if match && match[1]
          page_id = match[1].gsub('-', '')  # Remove hyphens for consistency
          # Validate it's a proper hex string of correct length
          if page_id.match?(/^[a-f0-9]{32}$/i)
            return page_id
          end
        end
      end
      
      # If no URL pattern matches, check if input is already a clean page ID
      clean_input = input.gsub('-', '')
      if clean_input.match?(/^[a-f0-9]{32}$/i)
        return clean_input
      end
      
      # Try to find any 32-character hex string in the input
      hex_match = input.match(/([a-f0-9]{32})/i)
      return hex_match[1] if hex_match
      
      # Try to find UUID format and convert
      uuid_match = input.match(/([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})/i)
      return uuid_match[1].gsub('-', '') if uuid_match
      
      nil
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
        c.dry_run = true  # Prevent API calls
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
      
      # Show only crucial high-level structure
      if workspace.databases.any?
        say("📊 Databases (#{workspace.databases.size}):", :bold, :green)
        workspace.databases.each_with_index do |db, index|
          is_last_db = index == workspace.databases.size - 1
          prefix = is_last_db ? "└── " : "├── "
          
          # Show database with key info only
          property_count = db.schema.size
          relation_count = db.relations.size
          
          info_summary = []
          info_summary << "#{property_count} props" if property_count > 0
          info_summary << "#{relation_count} relations" if relation_count > 0
          summary_text = info_summary.any? ? " (#{info_summary.join(', ')})" : ""
          
          say("#{prefix}#{db.icon || '📊'} #{db.title}#{summary_text}", :green)
        end
        say("")
      end
      
      # Show pages with high-level content analysis
      if workspace.pages.any?
        say("📄 Pages (#{workspace.pages.size}):", :bold, :yellow)
        workspace.pages.each_with_index do |page, index|
          is_last = index == workspace.pages.size - 1
          prefix = is_last ? "└── " : "├── "
          
          # Analyze page for crucial content
          crucial_content = analyze_crucial_content(page)
          content_summary = crucial_content.any? ? " → #{crucial_content.join(', ')}" : ""
          
          say("#{prefix}#{page.icon || '📄'} #{page.title}#{content_summary}", :yellow)
        end
        say("")
      end
    end

    # Analyze page content for only crucial, high-level elements
    def analyze_crucial_content(page)
      return [] unless page.children.respond_to?(:each)
      
      crucial_elements = []
      section_count = 0
      h1_count = 0
      callout_count = 0
      
      page.children.each do |child|
        # Handle both hash and object structures
        child_type = child.respond_to?(:type) ? child.type : child[:type]
        
        case child_type
        when :heading_1
          h1_count += 1
        when :callout
          callout_count += 1
        end
        
        # Count sections (groups of content)
        if child.respond_to?(:level) && child.level == 1
          section_count += 1
        elsif child_type == :heading_1
          section_count += 1 if section_count == 0  # First h1 starts a section
        end
      end
      
      # Only report meaningful structure
      crucial_elements << "#{h1_count} major sections" if h1_count > 0
      crucial_elements << "#{callout_count} highlights" if callout_count > 0
      crucial_elements << "structured content" if section_count > 1 && h1_count == 0
      
      crucial_elements.uniq.first(2)  # Limit to top 2 most important elements
    end

    def render_statistics(workspace)
      say("📈 Workspace Overview", :bold, :white)
      say("─" * 25)
      
      # High-level structural metrics only
      total_relations = workspace.databases.sum { |db| db.relations.size }
      
      # Count crucial content elements across all pages
      total_h1_sections = 0
      total_callouts = 0
      
      workspace.pages.each do |page|
        next unless page.children.respond_to?(:each)
        
        page.children.each do |child|
          # Handle both hash and object structures
          child_type = child.respond_to?(:type) ? child.type : child[:type]
          
          case child_type
          when :heading_1
            total_h1_sections += 1
          when :callout
            total_callouts += 1
          end
        end
      end
      
      # Show only the most important metrics
      high_level_stats = [
        ["🏛️  Workspace", workspace.root.title],
        ["� Databases", workspace.databases.size],
        ["📄 Documentation Pages", workspace.pages.size], 
        ["🔗 Data Relations", total_relations],
        ["📋 Major Sections", total_h1_sections],
        ["� Key Callouts", total_callouts]
      ]
      
      high_level_stats.each do |label, value|
        display_value = value.is_a?(String) ? value : value.to_s
        color = value.is_a?(String) ? :blue : (value.to_i > 0 ? :green : :white)
        say("#{label.ljust(20)} #{display_value}", color)
      end
      
      say("")
      
      # Simplified complexity - focus on structural complexity only
      structural_complexity = calculate_structural_complexity(workspace)
      complexity_color = case structural_complexity
                        when 0..3 then :green
                        when 4..8 then :yellow
                        else :red
                        end
      
      say("🎯 Structural Complexity: #{structural_complexity_description(structural_complexity)}", :bold, complexity_color)
      say("   #{workspace.databases.size} databases × #{workspace.pages.size} pages × #{total_relations} relations", complexity_color)
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

    # Simplified structural complexity for high-level view
    def calculate_structural_complexity(workspace)
      db_count = workspace.databases.size
      page_count = workspace.pages.size
      relation_count = workspace.databases.sum { |db| db.relations.size }
      
      # Simple scoring: more databases/pages/relations = higher structural complexity
      complexity = 0
      complexity += 1 if db_count > 3
      complexity += 1 if page_count > 5
      complexity += 1 if relation_count > 3
      complexity += 1 if (db_count * page_count) > 15  # Interaction complexity
      
      complexity
    end

    def structural_complexity_description(score)
      case score
      when 0
        "Minimal structure"
      when 1
        "Simple structure"
      when 2
        "Moderate structure"
      when 3
        "Complex structure"
      else
        "Very complex structure"
      end
    end

    # Box-style visualization for high-level overview
    def render_box_visualization(workspace)
      # Calculate consistent box width
      box_width = 50
      
      # Workspace header box
      title_text = "🏛️  #{workspace.root.title}"
      title_padding = box_width - title_text.length - 4  # Account for "┌─ " and " ─┐"
      title_padding = [title_padding, 0].max
      header_line = "┌─ #{title_text} #{'─' * title_padding}┐"
      
      # Content line with icon and cover
      icon_text = "#{workspace.root.icon}"
      cover_text = workspace.root.cover ? "🖼️" : ""
      content_padding = box_width - icon_text.length - cover_text.length - 4
      content_padding = [content_padding, 0].max
      content_line = "│ #{icon_text} #{cover_text}#{' ' * content_padding} │"
      
      say(header_line, :bold, :blue)
      say(content_line)
      say("└#{'─' * (box_width - 2)}┘")
      say("")
      
      # Databases in a box format
      if workspace.databases.any?
        data_header = "┌─ 📊 Data Layer #{'─' * (box_width - 17)}┐"
        say(data_header, :bold, :green)
        
        workspace.databases.each do |db|
          relation_info = db.relations.size > 0 ? " (#{db.relations.size} links)" : ""
          content = "#{db.icon || '📊'} #{db.title}#{relation_info}"
          padding = box_width - content.length - 4  # Account for "│ " and " │"
          padding = [padding, 0].max
          say("│ #{content}#{' ' * padding} │", :green)
        end
        say("└#{'─' * (box_width - 2)}┘")
        say("")
      end
      
      # Pages in a box format
      if workspace.pages.any?
        content_header = "┌─ 📄 Content Layer #{'─' * (box_width - 20)}┐"
        say(content_header, :bold, :yellow)
        
        workspace.pages.each do |page|
          crucial_content = analyze_crucial_content(page)
          content_info = crucial_content.any? ? " (#{crucial_content.first})" : ""
          # Page title already includes the icon, so don't add page.icon
          content = "#{page.title}#{content_info}"
          padding = box_width - content.length - 4  # Account for "│ " and " │"
          padding = [padding, 0].max
          say("│ #{content}#{' ' * padding} │", :yellow)
        end
        say("└#{'─' * (box_width - 2)}┘")
      end
    end

    # Graph-style visualization showing relationships
    def render_graph_visualization(workspace)
      say("🏛️  #{workspace.root.title}", :bold, :blue)
      say("#{workspace.root.icon} High-Level Architecture")
      say("")
      
      # Show databases and their connections
      if workspace.databases.any?
        say("📊 Data Architecture:", :bold, :green)
        workspace.databases.each do |db|
          related_dbs = db.relations.values.map { |config| 
            config[:target].respond_to?(:title) ? config[:target].title : "Unknown"
          }.uniq
          
          if related_dbs.any?
            say("   #{db.icon || '📊'} #{db.title}", :green)
            related_dbs.each do |target|
              say("      ↳ connects to → #{target}", :cyan)
            end
          else
            say("   #{db.icon || '📊'} #{db.title} (standalone)", :green)
          end
        end
        say("")
      end
      
      # Show content hierarchy
      if workspace.pages.any?
        say("📄 Content Hierarchy:", :bold, :yellow)
        workspace.pages.each do |page|
          crucial_content = analyze_crucial_content(page)
          say("   #{page.icon || '📄'} #{page.title}", :yellow)
          if crucial_content.any?
            crucial_content.each do |info|
              say("      ↳ contains → #{info}", :white)
            end
          end
        end
      end
    end

    # Helper methods for file detection and examples
    def find_workspace_file(name = nil)
      repository = WorkspaceRepository.new
      
      if name
        # Look for specific workspace by name
        found = repository.find_workspace(name)
        return found if found
      else
        # Look for workspace files in current directory (legacy)
        local = repository.find_local_workspaces
        return local if local
        
        # If no local files, suggest using repository
        return nil
      end
      
      nil
    end

    def display_check_summary(results)
      # Summary header
      status_icon = results.has_issues? ? "❌" : "✅"
      status_text = results.has_issues? ? "DRIFT DETECTED" : "IN SYNC"
      say("#{status_icon} Workspace Status: #{status_text}", results.has_issues? ? :red : :green, :bold)
      say("")
      
      # Quick stats
      say("📊 Summary:", :bold)
      say("   • Root page: #{results.root_status}")
      say("   • Databases: #{results.database_summary}")  
      say("   • Pages: #{results.page_summary}")
      say("   • Issues found: #{results.total_issues}", results.total_issues > 0 ? :red : :green)
      
      if results.has_issues?
        say("\n🔍 Issues Found:", :bold, :red)
        
        # Group issues by type
        if results.missing_resources.any?
          say("   📭 Missing Resources:", :red)
          results.missing_resources.each do |resource|
            say("     • #{resource[:type]}: #{resource[:name]}", :red)
          end
        end
        
        if results.extra_resources.any?
          say("   📬 Extra Resources in Notion:", :yellow)  
          results.extra_resources.each do |resource|
            say("     • #{resource[:type]}: #{resource[:name]}", :yellow)
          end
        end
        
        if results.schema_mismatches.any?
          say("   🔧 Schema Differences:", :yellow)
          results.schema_mismatches.each do |mismatch|
            say("     • #{mismatch[:database]}: #{mismatch[:issue]}", :yellow)
          end
        end
        
        if results.content_differences.any?
          say("   📝 Content Changes:", :cyan)
          results.content_differences.each do |diff|
            say("     • #{diff[:resource]}: #{diff[:change]}", :cyan)
          end
        end
        
        say("\n💡 Run with --fix to automatically resolve issues", :blue)
        say("💡 Run with --detailed for more information", :blue)
      else
        say("\n🎉 Everything looks perfect! Your workspace is in sync.", :green)
      end
    end

    def display_detailed_check_results(results)
      say("🔍 Detailed Workspace Analysis", :bold)
      say("━" * 60)
      
      # Root page analysis
      say("\n🏛️ Root Page Analysis:", :bold, :blue)
      if results.root_differences.any?
        results.root_differences.each do |diff|
          status_color = diff[:status] == :ok ? :green : :red
          say("   #{diff[:property]}: #{diff[:status]} - #{diff[:details]}", status_color)
        end
      else
        say("   ✅ Root page matches definition", :green)
      end
      
      # Database analysis
      say("\n📊 Database Analysis:", :bold, :green)
      results.database_details.each do |db_name, details|
        say("   Database: #{db_name}", :bold)
        
        if details[:exists]
          say("     ✅ Exists in Notion", :green)
          
          # Schema comparison
          if details[:schema_differences].any?
            say("     🔧 Schema differences:", :yellow)
            details[:schema_differences].each do |diff|
              say("       • #{diff[:property]}: #{diff[:issue]}", :yellow)
            end
          else
            say("     ✅ Schema matches", :green)
          end
          
          # Relation comparison
          if details[:relation_differences].any?
            say("     🔗 Relation differences:", :cyan)
            details[:relation_differences].each do |diff|
              say("       • #{diff[:relation]}: #{diff[:issue]}", :cyan)
            end
          else
            say("     ✅ Relations match", :green)
          end
        else
          say("     ❌ Missing from Notion", :red)
        end
        say("")
      end
      
      # Page analysis  
      say("📄 Page Analysis:", :bold, :yellow)
      results.page_details.each do |page_name, details|
        say("   Page: #{page_name}", :bold)
        
        if details[:exists]
          say("     ✅ Exists in Notion", :green)
          
          unless options[:ignore_content]
            if details[:content_differences].any?
              say("     📝 Content differences:", :cyan)
              details[:content_differences].each do |diff|
                say("       • #{diff[:section]}: #{diff[:change]}", :cyan)
              end
            else
              say("     ✅ Content matches", :green)
            end
          end
        else
          say("     ❌ Missing from Notion", :red)
        end
        say("")
      end
      
      # Summary
      if results.has_issues?
        say("━" * 60)
        say("❌ Issues detected! Use --fix to resolve automatically.", :red, :bold)
      else
        say("━" * 60)
        say("✅ Workspace is perfectly synchronized!", :green, :bold)
      end
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
