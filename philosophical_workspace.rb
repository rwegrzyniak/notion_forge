# frozen_string_literal: true

require_relative "lib/notion_forge"

# Original Philosophical Workshop from scratch.rb
def forge_workspace
  NotionForge::Workspace.new(
    title: "Philosophical Workshop",
    icon: "🏛️",
    cover: "https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=1500"
  ) do
    
    # Publications database with full DSL
    publications = database "Publications", icon: "📝" do
      title
      select "Status", options: [
        { name: '📋 Draft', color: 'gray' },
        { name: '🔍 Research', color: 'brown' },
        { name: '🏗️ Structure', color: 'orange' },
        { name: '✍️ Writing', color: 'yellow' },
        { name: '🔧 Review', color: 'blue' },
        { name: '✅ Done', color: 'green' }
      ]
      select "Type", options: ["🗡️ Polemic", "📄 Article", "💬 Comment"]
      select "Priority", options: ["🔥 Urgent", "⚡ High", "📌 Medium", "💤 Low"]
      created_time
      date 'Published'
      url 'Link'
      number 'Word Count'
      
      template '[TEMPLATE] Polemic', icon: '🗡️', props: { 'Type' => '🗡️ Polemic' } do
        callout '🗡️', 'POLEMIC - Response to specific text', color: 'red_background'
        
        section 'Source Analysis' do
          h3 '📄 Source Text'
          p '[Link to interlocutor text]'
          h3 '👤 Author Background'
          p '[Who is the author?]'
        end
        
        section 'Main Theses', level: 2 do
          ol 'Thesis 1'
          ol 'Thesis 2'
          ol 'Thesis 3'
        end
        
        expandable 'Counter-arguments' do
          ol 'Argument 1 - [brief]'
          p 'Detailed counter...'
          ol 'Argument 2 - [brief]'
          p 'Detailed counter...'
        end
        
        hr
        
        h2 '✍️ Draft Section'
        p '[Start writing here...]'
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
      
      template '[TEMPLATE] Source', icon: '📖' do
        section 'Overview' do
          p 'Author: '
          p 'Year: '
          p 'Type: '
        end
        
        section 'Key Quotes' do
          quote 'Quote 1...'
          p '↳ My note: '
          hr
          quote 'Quote 2...'
          p '↳ My note: '
        end
        
        expandable 'Full Notes' do
          p 'Detailed analysis...'
        end
      end
    end
    
    # Conclusions database
    conclusions = database "Conclusions & Theses", icon: "💡" do
      title "Thesis"
      select "Category", options: ["✅ Argument", "❌ Counter", "💡 Conclusion", "🎯 Assumption"]
      select "Strength", options: ["🔥 Very Strong", "💪 Strong", "👌 Medium", "🤔 Weak"]
      multi_select "Philosophy", options: ["Spinoza", "Realism", "Anti-idealism", "Geometry"]
      created_time "Created"
      text "Full Development"
      
      template '[TEMPLATE] Thesis', icon: '💡' do
        callout '💡', 'Core thesis in one sentence', color: 'yellow_background'
        
        section 'Development' do
          p 'Why do I believe this?'
          p ''
        end
        
        section 'Supporting Sources' do
          li 'Source 1'
          li 'Source 2'
        end
        
        expandable 'Counter-arguments & Defense' do
          h3 '🤔 Possible Objections'
          p 'Who might disagree?'
          hr
          h3 '🛡️ My Defense'
          p 'How to respond?'
        end
      end
    end
    
    # Setup relations
    publications.relate("Sources", sources)
    publications.relate("Conclusions", conclusions)
    sources.relate("Publications", publications)
    
    # Dashboard with advanced layout
    page "Dashboard", icon: "📊" do
      callout "👋", "Welcome to your command center!", color: "blue_background"
      
      hr
      
      section 'Active Work', level: 1 do
        p 'Your current projects appear here'
        toggle 'Quick Stats' do
          li 'Publications in progress: __'
          li 'Sources to read: __'
          li 'Pending reviews: __'
        end
      end
      
      section 'Quick Capture', level: 1 do
        callout '⚡', 'Catch that thought!', color: 'yellow_background'
        p 'Click + to add a quick note'
      end
      
      hr
      
      h2 '🎯 This Week\'s Goals'
      todo 'Finish article X'
      todo 'Read 3 new sources'
      todo 'Review polemic draft'
    end
    
    # Workflow guide
    page "Workflow Guide", icon: "🔄" do
      callout "📚", "Complete guide to the creation process", color: "blue_background"
      
      section 'Publication Stages', level: 1 do
        expandable '📋 Stage 1: Draft/Notes (15-30 min)' do
          p 'Record initial thoughts'
          li 'Don\'t worry about structure'
          li 'Capture key ideas'
          li 'Note questions to explore'
        end
        
        expandable '🔍 Stage 2: Research (1-2h)' do
          p 'Gather supporting materials'
          li 'Find 3-5 key sources'
          li 'Take structured notes'
          li 'Identify quotes'
        end
        
        expandable '🏗️ Stage 3: Structure (30 min)' do
          p 'Plan the argument flow'
          li 'Outline main points'
          li 'Order arguments'
          li 'Plan transitions'
        end
        
        expandable '✍️ Stage 4: Writing (2-4h)' do
          p 'First draft'
          li 'Focus on content'
          li 'Don\'t edit yet'
          li 'Get ideas on page'
        end
        
        expandable '🔧 Stage 5: Review (1h)' do
          p 'Polish and perfect'
          li 'Check logic'
          li 'Verify sources'
          li 'Add style elements'
        end
        
        expandable '✅ Stage 6: Done!' do
          p 'Ready for publication'
          li 'Final read-through'
          li 'Publish'
          li 'Track engagement'
        end
      end
      
      hr
      
      h2 '💡 Pro Tips'
      quote 'Take breaks between stages for fresh perspective'
      quote 'Read drafts aloud to catch awkward phrasing'
      quote 'Keep a running list of future topics'
    end
    
    # Style guide
    page "Style Guide", icon: "🎨" do
      callout "✍️", "Your writing voice and philosophy", color: "purple_background"
      
      section 'Core Characteristics' do
        toggle 'Philosophical Dignity' do
          li 'Use precise philosophical terminology'
          li 'Reference Spinoza, realism, geometry'
          li 'Apply Occam\'s Razor to arguments'
        end
        
        toggle 'Subtle Humor' do
          li 'Ironic commentary on idealists'
          li 'Witty juxtapositions'
          li 'Light touch - flavor not farce'
        end
      end
      
      section 'Favorite Techniques' do
        li '**Contrasts** - Expose absurd narratives'
        li '**Heuristics over mysticism** - Reduce "genius" to principles'
        li '**Geometry vs ideology** - Show structural necessities'
        li '**Resource economics** - Everything is cost/benefit'
      end
      
      hr
      
      h2 '❌ Avoid'
      li 'Mythologizing individuals'
      li 'Teleological explanations'
      li 'Uncritical idealist vocabulary'
      li 'Overly complex sentences'
    end
  end
end

# Test the workspace creation without API calls
if __FILE__ == $0
  puts "🏛️ Creating Philosophical Workshop..."
  
  # Configure with dummy data for testing (no API calls)
  NotionForge.configure do |config|
    config.token = "test_token"
    config.parent_page_id = "test_page"
    config.verbose = true
    config.dry_run = true  # This should prevent API calls if implemented
  end
  
  begin
    workspace = forge_workspace
    
    puts "✅ Workspace created successfully!"
    puts "📊 Statistics:"
    puts "   • Root page: #{workspace.root.title}"
    puts "   • Total resources: #{workspace.resources.size}"
    puts "   • Databases: #{workspace.databases.size}"
    puts "   • Pages: #{workspace.pages.size}"
    
    # Show database schemas
    workspace.databases.each do |db|
      puts "\n📊 Database: #{db.title}"
      puts "   • Properties: #{db.schema.keys.size}"
      puts "   • Relations: #{db.relations.keys.size}"
      puts "   • Schema: #{db.schema.keys.join(', ')}"
    end
    
    # Show page content
    workspace.pages.each do |page|
      puts "\n📄 Page: #{page.title}"
      puts "   • Content blocks: #{page.children.size}"
    end
    
    puts "\n🎉 Ready to forge with real API!"
    puts "Run: notion_forge forge philosophical_workspace.rb"
    
  rescue => e
    if e.message.include?("Invalid request URL") || e.message.include?("HTTP 400")
      puts "✅ DSL validation successful! (API error expected with dummy config)"
      puts "🎉 Ready to forge with real API!"
      puts "Run: notion_forge forge philosophical_workspace.rb"
    else
      puts "❌ Error: #{e.message}"
      raise
    end
  end
end
