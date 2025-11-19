# frozen_string_literal: true

require_relative "lib/notion_forge"

# Example workspace showcasing all NotionForge features
def forge_workspace
  NotionForge::Workspace.new(
    title: "NotionForge Demo Workspace",
    icon: "🎯",
    cover: "https://images.unsplash.com/photo-1551434678-e076c223a692?w=1500"
  ) do
    
    # Project Management Database
    projects = database "Projects", icon: "🚀" do
      title
      status options: [
        { name: "🆕 Planning", color: "gray" },
        { name: "🏗️ In Progress", color: "orange" },
        { name: "🔍 Review", color: "yellow" },
        { name: "✅ Complete", color: "green" },
        { name: "❄️ On Hold", color: "blue" },
        { name: "❌ Cancelled", color: "red" },
      ]
      select "Priority", options: [
        { name: "🔥 Critical", color: "red" },
        { name: "⚡ High", color: "orange" },
        { name: "📌 Medium", color: "yellow" },
        { name: "💤 Low", color: "gray" },
      ]
      multi_select "Tags", options: [
        "Frontend", "Backend", "Design", "Research", "Documentation"
      ]
      date "Due Date"
      number "Estimated Hours"
      url "Repository"
      checkbox "Reviewed"
      created_time "Created"
      text "Description"
      
      # Template for new projects
      template "🎯 Project Template", icon: "🎯", props: { 
        "Status" => "🆕 Planning",
        "Priority" => "📌 Medium"
      } do
        callout "🎯", "New Project Template", color: "blue_background"
        
        section "Project Overview" do
          h3 "🎯 Goals"
          li "Goal 1: [Define primary objective]"
          li "Goal 2: [Define secondary objective]"
          li "Goal 3: [Define success metrics]"
          
          h3 "🔍 Requirements"
          li "Requirement 1: [Technical requirement]"
          li "Requirement 2: [Business requirement]"
          li "Requirement 3: [User requirement]"
        end
        
        section "Planning" do
          h3 "📋 Tasks Breakdown"
          todo "Research and planning"
          todo "Design and architecture"
          todo "Implementation phase 1"
          todo "Testing and QA"
          todo "Documentation"
          todo "Deployment"
          
          h3 "🗓️ Timeline"
          p "Week 1: Research and planning"
          p "Week 2-3: Implementation"
          p "Week 4: Testing and deployment"
        end
        
        expandable "💡 Ideas & Notes" do
          p "Capture any ideas, concerns, or notes here..."
          quote "Remember to keep the user experience as the top priority"
        end
        
        hr
        
        h2 "📊 Progress Tracking"
        p "Update this section as the project progresses"
      end
    end
    
    # Team Members Database
    team = database "Team Members", icon: "👥" do
      title "Name"
      email "Email"
      select "Role", options: [
        "👨‍💻 Developer", "🎨 Designer", "📊 PM", "🧪 QA", "📝 Writer"
      ]
      select "Seniority", options: [
        "🌱 Junior", "🌿 Mid", "🌳 Senior", "🦅 Lead"
      ]
      multi_select "Skills", options: [
        "Ruby", "JavaScript", "Python", "Design", "Testing", "DevOps"
      ]
      checkbox "Active"
      date "Start Date"
      phone "Phone"
      created_time
    end
    
    # Tasks Database with Relations
    tasks = database "Tasks", icon: "✅" do
      title
      status options: [
        { name: "📋 Todo", color: "gray" },
        { name: "🔄 In Progress", color: "blue" },
        { name: "👀 Review", color: "yellow" },
        { name: "✅ Done", color: "green" },
        { name: "❌ Blocked", color: "red" },
      ]
      select "Priority", options: ["🔥 High", "📌 Medium", "💤 Low"]
      date "Due Date"
      number "Story Points", format: "number"
      checkbox "Billable"
      created_time
      text "Notes"
      
      # Relations to other databases
      relate "Project", projects
      relate "Assignee", team
    end
    
    # Meeting Notes Database
    meetings = database "Meeting Notes", icon: "📝" do
      title "Meeting Title"
      date "Date"
      select "Type", options: [
        "🎯 Planning", "📊 Review", "🤝 1-on-1", "🎉 Demo", "🔄 Retrospective"
      ]
      multi_select "Attendees", options: [
        "Alice", "Bob", "Charlie", "Diana", "Eve"
      ]
      text "Summary"
      checkbox "Action Items Completed"
      created_time
      
      relate "Related Project", projects
      
      template "📝 Meeting Template", icon: "📝", props: {
        "Type" => "🎯 Planning"
      } do
        callout "📝", "Meeting Notes Template", color: "yellow_background"
        
        section "Meeting Details", level: 1 do
          p "📅 Date: [Date]"
          p "⏰ Time: [Start] - [End]"
          p "👥 Attendees: [List attendees]"
          p "🎯 Purpose: [Meeting objective]"
        end
        
        section "Agenda", level: 1 do
          ol "Agenda item 1"
          ol "Agenda item 2"
          ol "Agenda item 3"
        end
        
        section "Discussion", level: 1 do
          h3 "📋 Key Points"
          li "Discussion point 1"
          li "Discussion point 2"
          
          h3 "🤔 Decisions Made"
          li "Decision 1: [What was decided]"
          li "Decision 2: [What was decided]"
        end
        
        section "Action Items", level: 1 do
          todo "Action item 1 - [Assignee] - [Due date]"
          todo "Action item 2 - [Assignee] - [Due date]"
          todo "Action item 3 - [Assignee] - [Due date]"
        end
        
        hr
        
        h2 "📋 Next Steps"
        p "What should happen before the next meeting?"
      end
    end
    
    # Documentation Hub
    page "📚 Documentation Hub", icon: "📚" do
      callout "📚", "Welcome to the Documentation Hub", color: "blue_background"
      p "Your central place for all project documentation, guides, and resources."
      
      section "🚀 Quick Start", level: 1 do
        h3 "For New Team Members"
        li "Read the [Team Handbook]"
        li "Set up your development environment"
        li "Complete the onboarding checklist"
        li "Schedule 1-on-1 with your manager"
        
        h3 "For New Projects"
        li "Use the Project Template"
        li "Set up repository and CI/CD"
        li "Define acceptance criteria"
        li "Create initial task breakdown"
      end
      
      section "📋 Processes & Guidelines", level: 1 do
        expandable "🔄 Development Workflow" do
          h3 "Git Workflow"
          ol "Create feature branch from main"
          ol "Make changes and commit frequently"
          ol "Open PR with clear description"
          ol "Get code review approval"
          ol "Merge to main and deploy"
          
          h3 "Code Standards"
          li "Follow Ruby Style Guide"
          li "Write tests for new features"
          li "Update documentation"
          li "Keep commits atomic and descriptive"
        end
        
        expandable "🧪 Testing Strategy" do
          li "Unit tests for all business logic"
          li "Integration tests for API endpoints"
          li "E2E tests for critical user journeys"
          li "Performance tests for bottlenecks"
        end
        
        expandable "🚀 Deployment Process" do
          ol "Run full test suite"
          ol "Update CHANGELOG.md"
          ol "Create release PR"
          ol "Deploy to staging"
          ol "QA testing"
          ol "Deploy to production"
          ol "Monitor metrics"
        end
      end
      
      section "🛠️ Tools & Resources", level: 1 do
        h3 "Development Tools"
        li "GitHub - Code repository"
        li "CircleCI - Continuous integration"
        li "Heroku - Application hosting"
        li "Sentry - Error monitoring"
        li "DataDog - Performance monitoring"
        
        h3 "Design Tools"
        li "Figma - UI/UX design"
        li "Notion - Documentation"
        li "Slack - Team communication"
        li "Zoom - Video meetings"
        
        h3 "Useful Links"
        li "[Company Wiki](https://wiki.company.com)"
        li "[API Documentation](https://api.company.com/docs)"
        li "[Style Guide](https://style.company.com)"
        li "[Support Portal](https://support.company.com)"
      end
      
      hr
      
      callout "💡", "Tip: Keep this documentation updated as processes evolve!", color: "yellow_background"
    end
    
    # Dashboard Page
    page "📊 Dashboard", icon: "📊" do
      callout "👋", "Welcome to your project dashboard!", color: "green_background"
      
      section "📈 Key Metrics", level: 1 do
        toggle "Project Overview" do
          li "Total Projects: 🔢 [Dynamic count]"
          li "Active Projects: 🔥 [In Progress count]"
          li "Completed This Month: ✅ [Completed count]"
          li "Team Members: 👥 [Team size]"
        end
        
        toggle "Task Summary" do
          li "Open Tasks: 📋 [Open tasks count]"
          li "In Progress: 🔄 [In progress count]"
          li "Blocked Tasks: ❌ [Blocked count]"
          li "Completed Today: ✅ [Daily completion]"
        end
      end
      
      section "🎯 This Week's Focus", level: 1 do
        callout "🔥", "High Priority Items", color: "red_background"
        todo "Complete API integration", checked: false
        todo "Review security audit", checked: false
        todo "Plan next sprint", checked: false
        
        callout "📅", "Upcoming Deadlines", color: "orange_background"
        li "🗓️ Project Alpha - Due Friday"
        li "📝 Documentation Review - Due Monday"
        li "🧪 QA Testing - Due Wednesday"
      end
      
      section "🤝 Team Updates", level: 1 do
        quote "Remember: Daily standups at 9:30 AM in #dev-team"
        quote "New hire Alice starts Monday - prepare onboarding"
        quote "Company all-hands Friday at 4 PM"
      end
      
      hr
      
      h2 "🚀 Quick Actions"
      li "➕ [Add New Project](notion://...)"
      li "📝 [Create Meeting Notes](notion://...)"
      li "✅ [Add Task](notion://...)"
      li "👥 [Add Team Member](notion://...)"
      
      hr
      
      code <<~RUBY, language: "ruby"
        # Example: NotionForge workspace creation
        workspace = NotionForge::Workspace.new(title: "My Workspace") do
          database "Projects", icon: "🚀" do
            title
            status options: ["Todo", "In Progress", "Done"]
            date "Due Date"
          end
          
          page "Dashboard", icon: "📊" do
            h1 "Welcome!"
            p "This workspace was created with code!"
          end
        end
        
        # Deploy with safety
        workspace.forge!(mode: :update)  # 🛡️ Safe & idempotent
      RUBY
    end
    
    # Style Guide & Best Practices
    page "🎨 Style Guide", icon: "🎨" do
      callout "🎨", "Workspace Style Guide & Best Practices", color: "purple_background"
      
      section "📝 Content Guidelines", level: 1 do
        h3 "✍️ Writing Style"
        li "Use clear, concise language"
        li "Start with action verbs for tasks"
        li "Include relevant emojis for visual scanning"
        li "Keep bullet points parallel in structure"
        
        h3 "🏷️ Naming Conventions"
        li "Projects: Use descriptive, unique names"
        li "Tasks: Start with verb (e.g., 'Implement user auth')"
        li "Pages: Include emoji for easy identification"
        li "Properties: Use consistent naming patterns"
      end
      
      section "🎯 Database Organization", level: 1 do
        expandable "Status Property Guidelines" do
          li "Always include a status property"
          li "Use consistent status names across databases"
          li "Color-code statuses meaningfully"
          li "Limit to 5-7 status options maximum"
        end
        
        expandable "Relation Best Practices" do
          li "Create bidirectional relations when useful"
          li "Use descriptive relation names"
          li "Don't over-relate - keep it simple"
          li "Consider rollup properties for summaries"
        end
        
        expandable "Template Strategy" do
          li "Create templates for common items"
          li "Include helpful prompts and structure"
          li "Use callouts for important information"
          li "Keep templates focused and actionable"
        end
      end
      
      section "🔧 Maintenance Tips", level: 1 do
        h3 "Regular Cleanup"
        todo "Archive completed projects monthly"
        todo "Review and update templates quarterly"
        todo "Clean up unused properties"
        todo "Update team member status"
        
        h3 "Performance Optimization"
        li "Limit views to essential filters"
        li "Use formulas sparingly"
        li "Archive old data regularly"
        li "Keep page content focused"
      end
      
      hr
      
      callout "💡", "Remember: This workspace grows with your team - keep iterating!", color: "blue_background"
    end
  end
end

# For CLI testing - this will be called by `notion_forge forge`
if __FILE__ == $0
  puts "🎯 Demo workspace defined!"
  puts "Run: notion_forge forge demo_workspace.rb"
end
