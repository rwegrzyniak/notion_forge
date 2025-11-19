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
        say(e.backtrace.join("
"), :red) if options[:verbose]
        exit 1
      end
    endlude Thor::Actions

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

    desc "init", "Initialize a new NotionForge configuration file"
    method_option :token, aliases: ["-t"], type: :string, desc: "Notion API token"
    method_option :parent_page_id, aliases: ["-p"], type: :string, desc: "Parent page ID"
    def init
      config_file = options[:config]
      
      if File.exist?(config_file)
        return say_error("Configuration file #{config_file} already exists!")
      end

      token = options[:token] || ask("Enter your Notion API token:")
      parent_page_id = options[:parent_page_id] || ask("Enter the parent page ID:")

      config = {
        "token" => token,
        "parent_page_id" => parent_page_id,
        "verbose" => false,
        "parallel" => false,
        "max_workers" => 4,
      }

      File.write(config_file, config.to_yaml)
      say("✅ Configuration file created: #{config_file}", :green)
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

      say("🔍 Validating: #{workspace_file}", :yellow)
      
      begin
        ruby_check = system("ruby -c #{workspace_file}")
        return say_error("❌ Syntax error in workspace file") unless ruby_check

        # Try to load without executing
        content = File.read(workspace_file)
        say("✅ Workspace file is valid", :green)
      rescue StandardError => e
        say_error("❌ Validation failed: #{e.message}")
        exit 1
      end
    end

    desc "examples", "Generate example workspace files"
    method_option :type, aliases: ["-t"], type: :string, default: "basic",
                  enum: ["basic", "philosophical", "project"],
                  desc: "Type of example workspace"
    def examples
      case options[:type]
      when "basic"
        create_basic_example
      when "philosophical"
        create_philosophical_example
      when "project"
        create_project_example
      end
    end

    desc "clean", "Clean up state files"
    method_option :force, aliases: ["-f"], type: :boolean, default: false, desc: "Force cleanup without confirmation"
    def clean
      state_files = Dir.glob("**/.notionforge.state.yml")
      
      if state_files.empty?
        say("No state files found", :yellow)
        return
      end

      say("Found state files:")
      state_files.each { |file| say("  • #{file}") }

      if options[:force] || yes?("\nDelete these files?")
        state_files.each do |file|
          File.delete(file)
          say("🗑️  Deleted: #{file}", :red)
        end
        say("✅ Cleanup complete", :green)
      else
        say("Cleanup cancelled", :yellow)
      end
    end

    private

    def load_configuration!
      config_file = options[:config]
      
      unless File.exist?(config_file)
        say_error("Configuration file not found: #{config_file}")
        say("Run 'notion_forge init' to create one", :yellow)
        exit 1
      end

      config = YAML.load_file(config_file)
      
      NotionForge.configure do |c|
        c.token = config["token"] || ENV["NOTION_TOKEN"]
        c.parent_page_id = config["parent_page_id"] || ENV["NOTION_PARENT_PAGE_ID"]
        c.verbose = config["verbose"] || false
        c.parallel = config["parallel"] || false
        c.max_workers = config["max_workers"] || 4
      end

      NotionForge.configuration.validate!
    rescue NotionForge::ConfigurationError => e
      say_error("Configuration Error: #{e.message}")
      exit 1
    end

    def find_workspace_file
      candidates = [
        "workspace.rb",
        "notionforge.rb",
        "forge.rb",
        Dir.glob("**/workspace.rb").first,
        Dir.glob("**/*forge*.rb").first,
      ].compact

      candidates.find { |file| File.exist?(file) }
    end

    def create_basic_example
      content = <<~RUBY
        # frozen_string_literal: true
        
        require "notion_forge"
        
        def forge_workspace
          NotionForge::Workspace.new(
            title: "My Workspace",
            icon: "🏠"
          ) do
            database "Tasks", icon: "✅" do
              title
              status options: ["Todo", "In Progress", "Done"]
              date "Due Date"
              select "Priority", options: ["High", "Medium", "Low"]
            end
            
            page "Welcome", icon: "👋" do
              h1 "Welcome to NotionForge!"
              p "This is your new workspace"
              callout "💡", "Edit this file to customize your workspace"
            end
          end
        end
      RUBY

      File.write("workspace.rb", content)
      say("✅ Created basic example: workspace.rb", :green)
    end

  def create_philosophical_example
    content = <<~RUBY
      # frozen_string_literal: true
      
      require "notion_forge"
      
      def forge_workspace
        NotionForge::Workspace.new(
          title: "Philosophical Workshop",
          icon: "🏛️",
          cover: "https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=1500"
        ) do
          
          # Publications database with full DSL
          publications = database "Publications", icon: "📝" do
            title
            status options: [
              { name: "📋 Draft", color: "gray" },
              { name: "🔍 Research", color: "brown" },
              { name: "🏗️ Structure", color: "orange" },
              { name: "✍️ Writing", color: "yellow" },
              { name: "🔧 Review", color: "blue" },
              { name: "✅ Done", color: "green" },
            ]
            select "Type", options: ["🗡️ Polemic", "📄 Article", "💬 Comment"]
            select "Priority", options: ["🔥 Urgent", "⚡ High", "📌 Medium", "💤 Low"]
            created_time
            date "Published"
            url "Link"
            number "Word Count"
            
            template "[TEMPLATE] Polemic", icon: "🗡️", props: { "Type" => "🗡️ Polemic" } do
              callout "🗡️", "POLEMIC - Response to specific text", color: "red_background"
              
              section "Source Analysis" do
                h3 "📄 Source Text"
                p "[Link to interlocutor text]"
                h3 "👤 Author Background"
                p "[Who is the author?]"
              end
              
              section "Main Theses", level: 2 do
                ol "Thesis 1"
                ol "Thesis 2"
                ol "Thesis 3"
              end
              
              expandable "Counter-arguments" do
                ol "Argument 1 - [brief]"
                p "Detailed counter..."
                ol "Argument 2 - [brief]"
                p "Detailed counter..."
              end
              
              hr
              
              h2 "✍️ Draft Section"
              p "[Start writing here...]"
            end
          end
          
          # Sources database
          sources = database "Sources & References", icon: "📚" do
            title
            text "Author"
            url "URL"
            select "Type", options: ["📖 Book", "🎓 Paper", "📰 Article", "🐦 Tweet"]
            select "Utility", options: ["🔥 Key", "⭐ Very Useful", "👍 Useful"]
            select "Credibility", options: ["✅ High", "👌 Medium", "⚠️ Verify"]
            created_time "Added"
            date "Read Date"
            checkbox "Cited"
          end
          
          # Conclusions database
          conclusions = database "Conclusions & Theses", icon: "💡" do
            title "Thesis"
            select "Category", options: ["✅ Argument", "❌ Counter", "💡 Conclusion", "🎯 Assumption"]
            select "Strength", options: ["🔥 Very Strong", "💪 Strong", "👌 Medium", "🤔 Weak"]
            multi_select "Philosophy", options: ["Spinoza", "Realism", "Anti-idealism", "Geometry"]
            created_time "Created"
            text "Full Development"
          end
          
          # Setup relations
          publications.relate("Sources", sources)
          publications.relate("Conclusions", conclusions)
          sources.relate("Publications", publications)
          
          # Dashboard
          page "Dashboard", icon: "📊" do
            callout "👋", "Welcome to your philosophical command center!", color: "blue_background"
            
            hr
            
            section "Active Work", level: 1 do
              p "Your current projects appear here"
              toggle "Quick Stats" do
                li "Publications in progress: __"
                li "Sources to read: __"
                li "Pending reviews: __"
              end
            end
            
            section "Quick Capture", level: 1 do
              callout "⚡", "Catch that thought!", color: "yellow_background"
              p "Click + to add a quick note"
            end
            
            hr
            
            h2 "🎯 This Week's Goals"
            todo "Finish article X"
            todo "Read 3 new sources"
            todo "Review polemic draft"
          end
          
          # Workflow guide
          page "Workflow Guide", icon: "🔄" do
            callout "📚", "Complete guide to the creation process", color: "blue_background"
            
            section "Publication Stages", level: 1 do
              expandable "📋 Stage 1: Draft/Notes (15-30 min)" do
                p "Record initial thoughts"
                li "Don't worry about structure"
                li "Capture key ideas"
                li "Note questions to explore"
              end
              
              expandable "🔍 Stage 2: Research (1-2h)" do
                p "Gather supporting materials"
                li "Find 3-5 key sources"
                li "Take structured notes"
                li "Identify quotes"
              end
              
              expandable "🏗️ Stage 3: Structure (30 min)" do
                p "Plan the argument flow"
                li "Outline main points"
                li "Order arguments"
                li "Plan transitions"
              end
              
              expandable "✍️ Stage 4: Writing (2-4h)" do
                p "First draft"
                li "Focus on content"
                li "Don't edit yet"
                li "Get ideas on page"
              end
              
              expandable "🔧 Stage 5: Review (1h)" do
                p "Polish and perfect"
                li "Check logic"
                li "Verify sources"
                li "Add style elements"
              end
              
              expandable "✅ Stage 6: Done!" do
                p "Ready for publication"
                li "Final read-through"
                li "Publish"
                li "Track engagement"
              end
            end
            
            hr
            
            h2 "💡 Pro Tips"
            quote "Take breaks between stages for fresh perspective"
            quote "Read drafts aloud to catch awkward phrasing"
            quote "Keep a running list of future topics"
          end
        end
      end
    RUBY

    File.write("philosophical_workspace.rb", content)
    say("✅ Created philosophical example: philosophical_workspace.rb", :green)
  end
  
  def create_project_example
    say("🚀 Project example would be created here", :blue)
  end

    def say_error(message)
      say("❌ #{message}", :red)
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
      # In production, consider using a more sophisticated key derivation
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

    def render_box_visualization(workspace)
      width = 60
      title_line = "│ #{workspace.root.title.center(width - 4)} │"
      
      say("┌" + "─" * (width - 2) + "┐")
      say(title_line, :bold, :blue)
      say("├" + "─" * (width - 2) + "┤")
      
      # Databases section
      if workspace.databases.any?
        say("│ 📊 DATABASES #{' ' * (width - 16)}│", :green)
        say("├" + "─" * (width - 2) + "┤")
        
        workspace.databases.each do |db|
          db_line = "│ #{db.icon || '📊'} #{db.title}"
          padding = width - 4 - db_line.length + 1
          say("#{db_line}#{' ' * padding}│", :green)
          
          if options[:show_properties] && !options[:compact]
            say("│   Properties: #{db.schema.keys.join(', ')}#{' ' * (width - 17 - db.schema.keys.join(', ').length)}│", :cyan)
          end
          
          if options[:show_relations] && db.relations.any?
            relations_text = db.relations.keys.join(', ')
            say("│   Relations: #{relations_text}#{' ' * (width - 16 - relations_text.length)}│", :magenta)
          end
        end
        say("├" + "─" * (width - 2) + "┤")
      end
      
      # Pages section
      if workspace.pages.any?
        say("│ 📄 PAGES #{' ' * (width - 12)}│", :yellow)
        say("├" + "─" * (width - 2) + "┤")
        
        workspace.pages.each do |page|
          page_line = "│ #{page.icon || '📄'} #{page.title}"
          blocks_info = options[:compact] ? "" : " (#{page.children.size})"
          padding = width - 4 - page_line.length - blocks_info.length + 1
          say("#{page_line}#{blocks_info}#{' ' * padding}│", :yellow)
        end
      end
      
      say("└" + "─" * (width - 2) + "┘")
      say("")
    end

    def render_graph_visualization(workspace)
      say("🌐 Workspace Graph Visualization", :bold, :blue)
      say("=" * 40)
      say("")
      
      # Create a network-style visualization
      nodes = []
      edges = []
      
      # Root node
      root_node = "📱 #{workspace.root.title}"
      nodes << { id: :root, label: root_node, type: :root }
      
      # Database nodes
      workspace.databases.each_with_index do |db, index|
        db_id = "db_#{index}".to_sym
        db_label = "#{db.icon || '📊'} #{db.title}"
        nodes << { id: db_id, label: db_label, type: :database }
        edges << { from: :root, to: db_id, type: :contains }
      end
      
      # Page nodes
      workspace.pages.each_with_index do |page, index|
        page_id = "page_#{index}".to_sym
        page_label = "#{page.icon || '📄'} #{page.title}"
        nodes << { id: page_id, label: page_label, type: :page }
        edges << { from: :root, to: page_id, type: :contains }
      end
      
      # Relation edges
      workspace.databases.each_with_index do |db, db_index|
        db_id = "db_#{db_index}".to_sym
        db.relations.each do |_name, config|
          if config[:target].respond_to?(:title)
            target_index = workspace.databases.find_index { |d| d.title == config[:target].title }
            if target_index
              target_id = "db_#{target_index}".to_sym
              edges << { from: db_id, to: target_id, type: :relation }
            end
          end
        end
      end
      
      # Render the graph
      render_graph_nodes_and_edges(nodes, edges)
    end

    def render_graph_nodes_and_edges(nodes, edges)
      # Group by type for better layout
      root_nodes = nodes.select { |n| n[:type] == :root }
      db_nodes = nodes.select { |n| n[:type] == :database }
      page_nodes = nodes.select { |n| n[:type] == :page }
      
      # Render root
      root_nodes.each do |node|
        say("    #{node[:label]}", :bold, :blue)
      end
      
      say("    │")
      say("    ├─── 📊 Databases")
      
      # Render databases with relations
      db_nodes.each_with_index do |node, index|
        is_last_db = index == db_nodes.size - 1
        connector = is_last_db ? "└" : "├"
        say("    │    #{connector}─── #{node[:label]}", :green)
        
        # Show relations
        if options[:show_relations]
          relations = edges.select { |e| e[:from] == node[:id] && e[:type] == :relation }
          relations.each_with_index do |edge, rel_index|
            target_node = db_nodes.find { |n| n[:id] == edge[:to] }
            if target_node
              is_last_rel = rel_index == relations.size - 1
              rel_prefix = is_last_db ? "         " : "    │    "
              rel_connector = is_last_rel ? "└" : "├"
              say("#{rel_prefix}#{rel_connector}─→ #{target_node[:label]}", :magenta)
            end
          end
        end
      end
      
      if page_nodes.any?
        say("    │")
        say("    └─── 📄 Pages")
        
        page_nodes.each_with_index do |node, index|
          is_last = index == page_nodes.size - 1
          connector = is_last ? "└" : "├"
          say("         #{connector}─── #{node[:label]}", :yellow)
        end
      end
      
      say("")
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
  end
end
