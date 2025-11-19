# NotionForge 🔥

Infrastructure as Code for Notion - A modern Ruby DSL for creating and managing Notion workspaces with databases, pages, and templates.

[![CI](https://github.com/johnny/notion_forge/workflows/CI/badge.svg)](https://github.com/johnny/notion_forge/actions)
[![Gem Version](https://badge.fury.io/rb/notion_forge.svg)](https://badge.fury.io/rb/notion_forge)
[![Ruby](https://img.shields.io/badge/ruby-3.3+-red.svg)](https://www.ruby-lang.org)

## Requirements 📋

- **Ruby 3.3+** - Uses cutting-edge Ruby features like pattern matching, endless methods, and modern syntax
- **Notion API token** - Get one from [Notion Developers](https://developers.notion.com/)

## Features ✨

- 🏗️ **Infrastructure as Code** - Define your Notion workspaces in Ruby
- 🚀 **Modern Ruby 3.3+** - Uses all the latest language features
- 🔄 **Idempotent Operations** - Safe to run multiple times
- 🛡️ **API Safety First** - Built-in rate limiting and error handling
- 🎨 **Rich DSL** - Intuitive and expressive syntax
- 📊 **Pattern Matching** - Leverages Ruby 3+ pattern matching
- 🔍 **Query Builder** - Powerful resource querying
- 📝 **Templates** - Reusable page and database templates
- 🧪 **Fiber Support** - Async operations with Fibers (safe for API)
- ⏱️ **Smart Rate Limiting** - Respects Notion API limits automatically

## Installation 📦

**Ruby 3.3+ Setup (RVM users):**
```bash
# Install Ruby 3.3.0 via RVM
rvm install 3.3.0
rvm use 3.3.0
rvm gemset create notion_forge
rvm use 3.3.0@notion_forge
```

**Install the gem:**

Add this line to your application's Gemfile:

```ruby
gem "notion_forge"
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install notion_forge
```

## Quick Start 🚀

1. **Initialize configuration:**
```bash
$ notion_forge init
```

2. **Create a workspace file:**
```ruby
# workspace.rb
require "notion_forge"

def forge_workspace
  NotionForge::Workspace.new(
    title: "My Awesome Workspace",
    icon: "🚀"
  ) do
    # Modern Ruby 3.3+ features in action!
    database "Tasks", icon: "✅" do
      title
      status options: [
        { name: "📋 Todo", color: "gray" },
        { name: "🔄 In Progress", color: "blue" },
        { name: "✅ Done", color: "green" },
      ]
      date "Due Date"
      select "Priority", options: ["🔥 Urgent", "⚡ High", "📌 Medium", "💤 Low"]
      
      # Pattern matching for templates
      template "Bug Report", icon: "🐛", props: { "Priority" => "🔥 Urgent" } do
        callout "🐛", "Bug Report Template", color: "red_background"
        
        section "Bug Details" do
          h3 "Steps to Reproduce"
          ol "Step 1"
          ol "Step 2"
          ol "Step 3"
        end
        
        section "Expected vs Actual" do
          toggle "Expected Behavior" do
            p "What should happen..."
          end
          
          toggle "Actual Behavior" do  
            p "What actually happened..."
          end
        end
      end
    end
    
    page "Welcome", icon: "👋" do
      h1 "Welcome to NotionForge!"
      p "This workspace was created with code! 🎉"
      
      callout "💡", "Edit workspace.rb to modify this workspace"
      
      # Showcase modern Ruby features
      code <<~RUBY, language: "ruby"
        # Pattern matching (Ruby 3+)
        case workspace
        in { databases: [db, *rest] } if db.title == "Tasks"
          puts "Found Tasks database!"
        end
        
        # Endless methods (Ruby 3+)
        def greet(name) = "Hello, \#{name}!"
        
        # Rightward assignment (Ruby 3+)
        workspace.databases.first => { title:, properties: }
      RUBY
    end
  end
end
```

3. **Forge your workspace:**
```bash
$ notion_forge forge workspace.rb
```

## CLI Usage 💻

```bash
# Initialize configuration
notion_forge init

# Create/update workspace
notion_forge forge workspace.rb

# Validate workspace file
notion_forge validate workspace.rb

# Generate examples
notion_forge examples --type basic

# Clean state files
notion_forge clean

# Force recreation with rate limiting
notion_forge forge --mode force --rate-limit 1.0
```

## DSL Reference 📚

### Workspace
```ruby
NotionForge::Workspace.new(title: "My Workspace", icon: "🏠") do
  # Define databases and pages here
end
```

### Database
```ruby
database "Project Tracker", icon: "📊" do
  title                                    # Title property
  text "Description"                       # Rich text
  status options: ["Active", "Done"]       # Status with options
  select "Priority", options: ["High", "Low"] # Select property
  date "Due Date"                          # Date property
  checkbox "Completed"                     # Checkbox
  number "Score"                           # Number
  url "Link"                              # URL
  email "Contact"                         # Email
  phone "Phone"                           # Phone number
  
  # Relations
  relate "Projects", other_database
end
```

### Page Content
```ruby
page "Documentation", icon: "📖" do
  h1 "Main Heading"
  h2 "Subheading"
  h3 "Sub-subheading"
  
  p "Regular paragraph text"
  
  callout "💡", "This is important info", color: "yellow_background"
  
  quote "Inspirational quote here"
  
  code "puts 'Hello, World!'", language: "ruby"
  
  todo "Task to complete", checked: false
  
  li "Bullet point"
  ol "Numbered item"
  
  hr  # Divider
  
  # Collapsible content
  toggle "Click to expand" do
    p "Hidden content here"
  end
end
```

## Configuration ⚙️

Create `notionforge.yml`:

```yaml
token: "secret_..."
parent_page_id: "abc123..."
verbose: true
parallel: false
max_workers: 4
```

Or use environment variables:
- `NOTION_TOKEN`
- `NOTION_PARENT_PAGE_ID`

## Development 🛠️

After checking out the repo, run:

```bash
bin/setup
bundle install
```

Run tests:
```bash
rake test
```

Run tests in parallel:
```bash
rake test TESTOPTS="--parallel"
```

Run RuboCop:
```bash
rake rubocop
```

Run all checks:
```bash
rake check
```

## Contributing 🤝

Bug reports and pull requests are welcome on GitHub at https://github.com/johnny/notion_forge.

## License 📄

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
