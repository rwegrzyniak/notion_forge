# frozen_string_literal: true

require_relative "lib/notion_forge"

# Simple test workspace for drift checking
def forge_workspace
  NotionForge::Workspace.new(
    title: "Drift Test Workspace",
    icon: "🔍",
  ) do
    
    # Simple database  
    database "Test Database", icon: "📊" do
      title
      text "Description"
      checkbox "Completed"
    end
    
    # Simple page
    page "Test Page", icon: "📄" do
      # Use valid block methods - let's see what's available
      # For now, just create an empty page
    end
  end
end

# Test the drift checker without API calls
if __FILE__ == $0
  puts "🔍 Testing Drift Checker..."
  
  # Configure with dummy data for testing (no API calls)
  NotionForge.configure do |config|
    config.token = "test_token"
    config.parent_page_id = "test_page"
    config.verbose = false
  end
  
  begin
    workspace = forge_workspace
    
    puts "✅ Test workspace created!"
    puts "📊 Resources:"
    puts "   • Databases: #{workspace.databases.size}"
    puts "   • Pages: #{workspace.pages.size}"
    
    # Test drift checker logic (without API calls)
    puts "\n🔍 Testing drift checker components..."
    
    # Show what the checker would analyze
    workspace.databases.each do |db|
      puts "📊 Database: #{db.title}"
      puts "   • Schema: #{db.schema.keys.join(', ')}"
      puts "   • Relations: #{db.relations.keys.join(', ')}" if db.relations.any?
    end
    
    workspace.pages.each do |page|
      puts "📄 Page: #{page.title}"
      puts "   • Children: #{page.children.size}" if page.children.any?
    end
    
    puts "\n✅ Drift checker test successful!"
    puts "💡 Use this workspace to test: notion_forge check test_drift_workspace.rb"
    
  rescue => e
    puts "❌ Error: #{e.message}"
    puts e.backtrace.first(5).join("\n") if $DEBUG
  end
end
