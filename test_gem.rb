#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple test script to verify gem structure works
$LOAD_PATH.unshift File.expand_path("lib", __dir__)

begin
  require "notion_forge"
  
  puts "✅ NotionForge loaded successfully!"
  puts "📦 Version: #{NotionForge::VERSION}"
  
  # Test configuration
  NotionForge.configure do |config|
    config.token = "test_token"
    config.parent_page_id = "test_page"
    config.verbose = true
  end
  
  puts "⚙️  Configuration works!"
  
  # Test workspace creation (without API calls)
  workspace = NotionForge::Workspace.new(title: "Test Workspace", icon: "🧪") do
    database "Test DB", icon: "📊" do
      title
      status options: ["Todo", "Done"]
      text "Description"
    end
    
    page "Test Page", icon: "📄" do
      h1 "Hello World"
      p "This is a test page"
      callout "✅", "Gem structure works!"
    end
  end
  
  puts "🏗️  Workspace creation works!"
  puts "📊 Resources: #{workspace.resources.size}"
  puts "   • Databases: #{workspace.databases.size}"
  puts "   • Pages: #{workspace.pages.size}"
  
  # Test pattern matching
  case workspace
  in { resources: [db, page] }
    puts "🎯 Pattern matching works!"
    puts "   • Database: #{db.title}"
    puts "   • Page: #{page.title}"
  end
  
  puts "\n🎉 All gem components working correctly!"
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts "📍 Backtrace:"
  puts e.backtrace.first(5).join("\n")
  exit 1
end
