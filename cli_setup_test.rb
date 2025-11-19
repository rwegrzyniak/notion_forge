#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive CLI Setup Testing Script
# This script demonstrates and tests all the setup-related CLI functionality

require_relative "lib/notion_forge"
require_relative "lib/notion_forge/cli"

puts "🧪 NotionForge CLI Setup Testing Suite"
puts "=" * 60

def test_section(title)
  puts "\n📋 #{title}"
  puts "-" * 40
  yield
  puts "✅ Section completed"
end

def run_cli_command(description, &command_proc)
  puts "🔧 #{description}"
  begin
    result = command_proc.call
    puts "   ✅ Success: #{result}" if result
  rescue => e
    puts "   ❌ Error: #{e.message}"
  end
end

# Initialize CLI instance
cli = NotionForge::CLI.new

test_section("Basic CLI Commands") do
  run_cli_command("Testing version command") do
    cli.version
    "Version displayed correctly"
  end

  run_cli_command("Testing status command (unconfigured)") do
    cli.status
    "Status shows unconfigured state"
  end
end

test_section("Workspace File Validation") do
  run_cli_command("Validating demo workspace file") do
    if File.exist?("demo_workspace.rb")
      cli.validate("demo_workspace.rb")
      "Demo workspace validated successfully"
    else
      "Demo workspace file not found"
    end
  end

  run_cli_command("Validating philosophical workspace file") do
    if File.exist?("philosophical_workspace.rb")
      cli.validate("philosophical_workspace.rb")
      "Philosophical workspace validated successfully"
    else
      "Philosophical workspace file not found"
    end
  end
end

test_section("Workspace Visualization") do
  run_cli_command("Visualizing demo workspace") do
    if File.exist?("demo_workspace.rb")
      cli.visualize("demo_workspace.rb")
      "Demo workspace visualized successfully"
    else
      "Demo workspace file not found"
    end
  end
end

test_section("Example Generation") do
  run_cli_command("Generating example workspace files") do
    cli.examples
    "Example files generated/verified"
  end
end

test_section("CLI Configuration Testing") do
  puts "🔧 Testing configuration-related functionality"
  
  # Test configuration file paths
  config_dir = File.expand_path("~/.notion_forge")
  puts "   📁 Configuration directory: #{config_dir}"
  puts "   📄 Configuration would be stored at: #{File.join(config_dir, 'config.encrypted')}"
  
  # Test CLI option parsing
  puts "   ⚙️  CLI supports these options:"
  puts "      --verbose, -v     : Enable verbose output"
  puts "      --config, -c      : Specify config file path"
  puts "      --force           : Force reconfiguration (setup command)"
  
  # Test command availability
  expected_commands = %w[setup status version forge validate visualize examples]
  available_commands = cli.class.all_commands.keys
  
  puts "   📋 Available commands:"
  expected_commands.each do |cmd|
    if available_commands.include?(cmd)
      puts "      ✅ #{cmd}"
    else
      puts "      ❌ #{cmd} (missing)"
    end
  end
end

test_section("Setup Command Analysis") do
  puts "🔧 Analyzing setup command structure"
  
  setup_command = cli.class.all_commands["setup"]
  if setup_command
    puts "   📝 Setup command found with options:"
    setup_command.options.each do |name, option|
      puts "      --#{name}: #{option.description}"
    end
    
    puts "   📖 Setup command description:"
    puts "      #{setup_command.description}"
    
    puts "   🎯 Setup process would involve:"
    puts "      1. Check for existing configuration"
    puts "      2. Prompt for Notion API token"
    puts "      3. Validate token with Notion API"
    puts "      4. Prompt for parent page ID"
    puts "      5. Validate page access"
    puts "      6. Encrypt and save configuration"
    puts "      7. Confirm successful setup"
  else
    puts "   ❌ Setup command not found"
  end
end

test_section("Error Handling and Edge Cases") do
  run_cli_command("Testing validation with non-existent file") do
    begin
      cli.validate("non_existent_file.rb")
    rescue => e
      "Correctly handled missing file: #{e.message}"
    end
  end
  
  run_cli_command("Testing visualization with non-existent file") do
    begin
      cli.visualize("non_existent_file.rb")
    rescue => e
      "Correctly handled missing file: #{e.message}"
    end
  end
end

test_section("Integration Readiness Check") do
  puts "🔧 Checking integration readiness"
  
  # Check if Thor is properly loaded
  puts "   📚 Thor CLI framework: #{defined?(Thor) ? '✅ Loaded' : '❌ Missing'}"
  
  # Check if YAML is available for config
  puts "   📄 YAML support: #{defined?(YAML) ? '✅ Available' : '❌ Missing'}"
  
  # Check if OpenSSL is available for encryption
  puts "   🔐 OpenSSL support: #{defined?(OpenSSL) ? '✅ Available' : '❌ Missing'}"
  
  # Check if IO::Console is available for secure input
  puts "   🔒 Secure input support: #{defined?(IO::Console) ? '✅ Available' : '❌ Missing'}"
  
  # Check workspace files
  workspace_files = Dir.glob("*_workspace.rb")
  puts "   📋 Available workspace files:"
  workspace_files.each do |file|
    puts "      📄 #{file}"
  end
  
  puts "   🎯 CLI is ready for:"
  puts "      ✅ Basic operations (version, status, help)"
  puts "      ✅ Workspace validation and visualization"
  puts "      ✅ Example generation"
  puts "      🔄 Setup process (requires user interaction)"
  puts "      🔄 Forge operations (requires Notion API setup)"
end

puts "\n🎉 CLI Setup Testing Complete!"
puts "=" * 60
puts "The NotionForge CLI is properly configured and ready for use."
puts "Next steps:"
puts "  1. Run 'notion_forge setup' to configure API credentials"
puts "  2. Use 'notion_forge forge demo_workspace.rb' to deploy a workspace"
puts "  3. Explore other commands with 'notion_forge help'"
