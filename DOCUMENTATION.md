# NotionForge DSL Reference Guide

## Overview

NotionForge is a Ruby-based Domain-Specific Language (DSL) for programmatically creating and managing Notion workspaces. It provides a declarative, type-safe way to define complex workspace structures that can be deployed to Notion via API.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Core Concepts](#core-concepts)
3. [Workspace Definition](#workspace-definition)
4. [Database Schema](#database-schema)
5. [Page Content](#page-content)
6. [Relations & References](#relations--references)
7. [Advanced Features](#advanced-features)
8. [Complete Examples](#complete-examples)

---

## Getting Started

### Basic Workspace Structure

Every NotionForge workspace starts with a root page that contains databases and pages:

```ruby
NotionForge::Workspace.new(title: "My Workspace", icon: "🏛️") do
  # Databases and pages go here
end
```

### Minimal Example

```ruby
NotionForge::Workspace.new(title: "Task Manager", icon: "✅") do
  database "Tasks", icon: "📋" do
    title  # Required: every database needs a title property
    status options: ["Todo", "In Progress", "Done"]
    date "Due Date"
  end
end
```

---

## Core Concepts

### Workspace Hierarchy

```
Workspace (Root Page)
├── Databases (structured data tables)
│   ├── Properties (columns/fields)
│   └── Relations (connections between databases)
└── Pages (documentation/content)
    └── Content Blocks (headings, paragraphs, etc.)
```

### Resource Types

| Type | Purpose | Example |
|------|---------|---------|
| `Workspace` | Root container | Main workspace page |
| `Database` | Structured data | Task lists, CRM, inventory |
| `Page` | Documentation | Guides, wikis, notes |
| `Property` | Database field | Title, status, date, number |
| `Relation` | Cross-database link | Tasks → Projects |
| `Block` | Content element | Headings, text, callouts |

---

## Workspace Definition

### Creating a Workspace

```ruby
NotionForge::Workspace.new(
  title: "Project Hub",      # Required: workspace name
  icon: "🚀",                # Optional: emoji icon
  cover: "https://...",      # Optional: cover image URL
  description: "Central hub" # Optional: workspace description
) do
  # Content goes here
end
```

### Configuration Options

```ruby
# Configure API settings globally
NotionForge.configure do |config|
  config.token = "secret_xxx..."           # Notion API token
  config.parent_page_id = "abc123..."      # Where to create workspace
  config.verbose = true                    # Enable detailed logging
  config.rate_limit = 0.5                  # Delay between API calls (seconds)
end
```

### Deployment Modes

```ruby
workspace.forge!(mode: :update)  # Default: idempotent updates
workspace.forge!(mode: :fresh)   # Only create if doesn't exist
workspace.forge!(mode: :force)   # Delete and recreate everything
```

---

## Database Schema

### Property Types

#### 1. Title (Required)

Every database must have exactly one title property:

```ruby
database "Projects" do
  title                    # Default name: "Name"
  title "Project Name"     # Custom name
end
```

#### 2. Text Properties

```ruby
database "Contacts" do
  title
  text "Notes"             # Multi-line text
  rich_text "Description"  # Formatted text (alias for text)
  email "Email Address"    # Email validation
  phone_number "Phone"     # Phone number
  url "Website"            # URL validation
end
```

#### 3. Number Properties

```ruby
database "Products" do
  title
  number "Price"                        # Any number
  number "Quantity", format: "number"   # Integer formatting
  number "Percentage", format: "percent" # Show as percentage
  number "Rating", format: "number_with_commas"
end
```

#### 4. Select & Multi-Select

```ruby
database "Tasks" do
  title
  
  # Single choice
  select "Priority", options: ["High", "Medium", "Low"]
  select "Status", options: ["Todo", "Doing", "Done"], 
         default: "Todo"
  
  # Multiple choices
  multi_select "Tags", options: ["Important", "Urgent", "Review"]
  multi_select "Categories", options: ["Work", "Personal", "Health"]
end
```

#### 5. Date Properties

```ruby
database "Events" do
  title
  
  date "Start Date"              # Single date
  date "Due Date"                # Deadline
  created_time "Created"         # Auto-populated creation time
  last_edited_time "Modified"    # Auto-populated edit time
end
```

#### 6. Checkbox & Status

```ruby
database "Tasks" do
  title
  
  checkbox "Completed"           # Boolean true/false
  checkbox "Archived"
  
  # Status with workflow states
  status options: ["Not Started", "In Progress", "Done"]
end
```

#### 7. People & Relations

```ruby
database "Projects" do
  title
  
  people "Assigned To"           # Notion users
  people "Team Members"
  
  # Relations defined separately (see Relations section)
end
```

#### 8. Advanced Properties

```ruby
database "Files" do
  title
  
  files "Attachments"            # File uploads
  formula "Total", expression: "prop('Price') * prop('Quantity')"
  rollup "Sum", relation: "Items", property: "Price", function: "sum"
  
  # Auto-incrementing ID
  auto_increment "ID"
end
```

### Database Options

```ruby
database "Projects", 
  icon: "📊",                    # Database icon
  description: "All projects",   # Database description
  inline: true                   # Create as inline database (default: false)
do
  # Properties...
end
```

---

## Page Content

### Content Blocks

#### Text Blocks

```ruby
page "Welcome", icon: "👋" do
  h1 "Main Title"                    # Heading 1
  h2 "Subtitle"                      # Heading 2
  h3 "Section"                       # Heading 3
  
  p "Regular paragraph text"         # Paragraph
  p "**Bold** and *italic* text"     # Markdown formatting
  
  quote "Important quote"            # Quote block
  
  callout "💡 Pro tip: Use callouts for highlights", 
          type: :info                # Info, warning, error
end
```

#### Lists

```ruby
page "Guide" do
  h2 "Features"
  
  # Bulleted list
  bullet "First item"
  bullet "Second item"
  bullet "Third item"
  
  # Numbered list
  numbered "Step 1"
  numbered "Step 2"
  numbered "Step 3"
  
  # Toggle list (collapsible)
  toggle "Click to expand" do
    p "Hidden content"
  end
  
  # Checklist
  todo "Task 1", checked: true
  todo "Task 2", checked: false
end
```

#### Code Blocks

```ruby
page "Documentation" do
  code <<~RUBY, language: "ruby"
    def hello
      puts "Hello, World!"
    end
  RUBY
  
  code "console.log('JS code')", language: "javascript"
end
```

#### Dividers & Spacing

```ruby
page "Layout" do
  p "Section 1"
  divider                            # Horizontal line
  p "Section 2"
  
  blank_line                         # Empty space
  blank_line 3                       # Multiple blank lines
end
```

#### Media & Embeds

```ruby
page "Portfolio" do
  image "https://example.com/photo.jpg",
        caption: "Project screenshot"
  
  video "https://youtube.com/watch?v=..."
  
  embed "https://figma.com/...",     # Embed external content
        caption: "Design mockup"
  
  bookmark "https://notion.so",      # Link preview
           caption: "Reference"
end
```

#### Tables of Contents

```ruby
page "Guide" do
  table_of_contents                  # Auto-generated TOC
  
  h2 "Introduction"
  p "Content..."
  
  h2 "Getting Started"
  p "More content..."
end
```

### Page Options

```ruby
page "About", 
  icon: "ℹ️",                        # Page icon
  cover: "https://...",              # Cover image
  full_width: true                   # Full page width
do
  # Content blocks...
end
```

---

## Relations & References

### Database Relations

Relations create connections between databases:

```ruby
NotionForge::Workspace.new(title: "CRM") do
  database "Companies", icon: "🏢" do
    title "Company Name"
  end
  
  database "Contacts", icon: "👤" do
    title "Contact Name"
    email "Email"
    
    # One-to-many: Contact belongs to Company
    relation "Company", 
             target: "Companies",
             type: :single          # single or multi
  end
  
  database "Deals", icon: "💰" do
    title "Deal Name"
    number "Amount"
    
    # Many-to-one: Deal has one Contact
    relation "Contact",
             target: "Contacts",
             type: :single
    
    # Many-to-many: Deal can have multiple Companies
    relation "Related Companies",
             target: "Companies",
             type: :multi
  end
end
```

### Relation Types

```ruby
# Single relation (one-to-one or many-to-one)
relation "Assigned To", 
         target: "Users",
         type: :single

# Multiple relations (many-to-many)
relation "Tags",
         target: "Tag Database",
         type: :multi

# Bidirectional with custom names
relation "Tasks",
         target: "Task Database",
         type: :multi,
         reverse_name: "Project"  # Name in target database
```

### Rollup Properties

Aggregate data from related databases:

```ruby
database "Projects" do
  title
  
  relation "Tasks", target: "Task Database"
  
  # Count related tasks
  rollup "Task Count",
         relation: "Tasks",
         property: "Name",
         function: "count"
  
  # Sum of task estimates
  rollup "Total Hours",
         relation: "Tasks",
         property: "Time Estimate",
         function: "sum"
  
  # Other functions: average, min, max, median, etc.
end
```

### Formula Properties

Calculate values based on other properties:

```ruby
database "Invoices" do
  title
  number "Subtotal"
  number "Tax Rate"
  
  # Simple calculation
  formula "Tax Amount",
          expression: 'prop("Subtotal") * prop("Tax Rate")'
  
  # Complex formula
  formula "Total",
          expression: 'prop("Subtotal") + prop("Tax Amount")'
  
  # Conditional formula
  formula "Status Color",
          expression: 'if(prop("Paid"), "🟢", "🔴")'
end
```

---

## Advanced Features

### Templates & Helpers

```ruby
# Define reusable components
def task_schema
  title "Task Name"
  status options: ["Todo", "In Progress", "Done"]
  date "Due Date"
  people "Assignee"
  select "Priority", options: ["High", "Medium", "Low"]
end

# Use in multiple databases
database "Personal Tasks" do
  task_schema
  checkbox "Personal"
end

database "Work Tasks" do
  task_schema
  text "Project Code"
end
```

### Dynamic Content

```ruby
# Generate content programmatically
page "Team Directory" do
  h1 "Team Members"
  
  team_members = ["Alice", "Bob", "Charlie"]
  team_members.each do |member|
    h2 member
    p "Email: #{member.downcase}@company.com"
    divider
  end
end
```

### Conditional Logic

```ruby
database "Products" do
  title
  number "Price"
  
  # Conditional property
  if ENV['ENABLE_INVENTORY']
    number "Stock Quantity"
    checkbox "Track Inventory"
  end
end
```

### Nested Structures

```ruby
page "Documentation" do
  h1 "API Reference"
  
  toggle "Authentication" do
    h3 "Overview"
    p "Authentication methods..."
    
    code <<~RUBY, language: "ruby"
      api.authenticate(token: "...")
    RUBY
    
    toggle "Advanced" do
      p "OAuth flow details..."
    end
  end
end
```

---

## Complete Examples

### 1. Project Management System

```ruby
NotionForge::Workspace.new(title: "Project Manager", icon: "📊") do
  # Projects database
  database "Projects", icon: "📁" do
    title "Project Name"
    select "Status", options: ["Planning", "Active", "On Hold", "Complete"]
    date "Start Date"
    date "End Date"
    people "Project Manager"
    text "Description"
  end
  
  # Tasks database with project relation
  database "Tasks", icon: "✅" do
    title "Task Name"
    relation "Project", target: "Projects", type: :single
    status options: ["Todo", "In Progress", "Review", "Done"]
    select "Priority", options: ["High", "Medium", "Low"]
    date "Due Date"
    people "Assigned To"
    number "Estimated Hours"
  end
  
  # Team members
  database "Team", icon: "👥" do
    title "Name"
    email "Email"
    phone_number "Phone"
    select "Role", options: ["Developer", "Designer", "Manager"]
  end
  
  # Welcome page
  page "Getting Started", icon: "👋" do
    h1 "Welcome to Project Manager"
    
    callout "💡 This workspace helps you manage projects and tasks efficiently"
    
    h2 "Quick Start"
    numbered "Create a new project in the Projects database"
    numbered "Add team members to the Team database"
    numbered "Create tasks and assign them to projects"
    
    divider
    
    h2 "Key Features"
    bullet "Track project status and timelines"
    bullet "Assign tasks to team members"
    bullet "Monitor progress with status tracking"
    bullet "Estimate and track work hours"
  end
end
```

### 2. CRM System

```ruby
NotionForge::Workspace.new(title: "CRM", icon: "🤝") do
  # Companies
  database "Companies", icon: "🏢" do
    title "Company Name"
    url "Website"
    email "Primary Email"
    phone_number "Phone"
    select "Industry", options: ["Technology", "Finance", "Healthcare", "Retail"]
    select "Size", options: ["1-10", "11-50", "51-200", "201-500", "500+"]
    text "Notes"
  end
  
  # Contacts
  database "Contacts", icon: "👤" do
    title "Full Name"
    relation "Company", target: "Companies", type: :single
    email "Email"
    phone_number "Phone"
    select "Role", options: ["Decision Maker", "Influencer", "User"]
    date "Last Contact"
    text "Notes"
  end
  
  # Deals
  database "Deals", icon: "💰" do
    title "Deal Name"
    relation "Company", target: "Companies", type: :single
    relation "Primary Contact", target: "Contacts", type: :single
    number "Amount", format: "dollar"
    select "Stage", options: ["Prospecting", "Qualification", "Proposal", "Negotiation", "Closed Won", "Closed Lost"]
    date "Expected Close Date"
    people "Account Owner"
    number "Probability", format: "percent"
    
    # Calculated field
    formula "Weighted Value", 
            expression: 'prop("Amount") * prop("Probability")'
  end
  
  # Activities
  database "Activities", icon: "📞" do
    title "Activity"
    relation "Deal", target: "Deals", type: :single
    relation "Contact", target: "Contacts", type: :single
    select "Type", options: ["Call", "Email", "Meeting", "Demo"]
    date "Date"
    text "Notes"
    checkbox "Follow-up Required"
  end
  
  # Sales playbook page
  page "Sales Playbook", icon: "📖" do
    h1 "Sales Process"
    
    h2 "Deal Stages"
    
    toggle "1. Prospecting" do
      p "Identify potential customers and qualify leads"
      bullet "Research company background"
      bullet "Identify decision makers"
      bullet "Schedule discovery call"
    end
    
    toggle "2. Qualification" do
      p "Understand customer needs and fit"
      bullet "Conduct needs assessment"
      bullet "Validate budget and timeline"
      bullet "Present initial solution"
    end
    
    toggle "3. Proposal" do
      p "Present formal proposal and pricing"
      bullet "Create custom proposal"
      bullet "Schedule presentation"
      bullet "Address questions"
    end
    
    divider
    
    h2 "Best Practices"
    callout "⭐ Always log activities in the CRM for tracking"
    callout "📊 Update deal probability based on customer engagement"
    callout "🎯 Focus on high-value, high-probability deals"
  end
end
```

### 3. Content Management System

```ruby
NotionForge::Workspace.new(title: "Content Hub", icon: "📝") do
  # Content pieces
  database "Content", icon: "📄" do
    title "Title"
    select "Type", options: ["Blog Post", "Article", "Video", "Podcast", "Newsletter"]
    select "Status", options: ["Idea", "Outline", "Draft", "Review", "Published"]
    date "Publish Date"
    people "Author"
    relation "Topic", target: "Topics", type: :single
    multi_select "Tags", options: ["Tutorial", "News", "Opinion", "Case Study"]
    url "Published URL"
    number "Word Count"
  end
  
  # Topics/Categories
  database "Topics", icon: "🏷️" do
    title "Topic Name"
    text "Description"
    rollup "Content Count",
           relation: "Content",  # Reverse relation
           property: "Title",
           function: "count"
  end
  
  # Editorial calendar
  database "Calendar", icon: "📅" do
    title "Week"
    date "Week Start"
    relation "Scheduled Content", target: "Content", type: :multi
    rollup "Posts This Week",
           relation: "Scheduled Content",
           property: "Title",
           function: "count"
  end
  
  # Content guidelines
  page "Writing Guide", icon: "✍️" do
    table_of_contents
    
    h1 "Content Creation Guidelines"
    
    h2 "Blog Post Structure"
    numbered "Compelling headline (50-70 characters)"
    numbered "Introduction (hook + context)"
    numbered "Main body (2-3 key points)"
    numbered "Conclusion with CTA"
    
    h2 "SEO Checklist"
    todo "Include focus keyword in title"
    todo "Add meta description (150-160 chars)"
    todo "Use H2/H3 subheadings"
    todo "Include internal links"
    todo "Optimize images with alt text"
    
    h2 "Voice & Tone"
    callout "🎯 Professional yet approachable. Avoid jargon unless necessary."
    
    bullet "Be concise and clear"
    bullet "Use active voice"
    bullet "Write for scanning (short paragraphs, bullet points)"
    bullet "Include examples and stories"
  end
end
```

---

## Technical Specifications

### API Integration

NotionForge uses the official Notion API (v2022-06-28):

- **Authentication**: Bearer token (Integration secrets)
- **Rate Limiting**: Built-in delay mechanism (configurable)
- **Error Handling**: Automatic retries with exponential backoff
- **Idempotency**: Update mode prevents duplicates

### Supported Notion API Endpoints

```
POST   /v1/pages          - Create pages
PATCH  /v1/pages/:id      - Update pages
GET    /v1/pages/:id      - Retrieve pages
POST   /v1/databases      - Create databases
PATCH  /v1/databases/:id  - Update database schemas
POST   /v1/blocks/:id/children - Append blocks
```

### Security

- **Credential Encryption**: AES-256-GCM encryption
- **Secure Storage**: `~/.notion_forge/secrets` (0600 permissions)
- **Token Validation**: Automatic verification before operations
- **Sandboxed Execution**: Safe DSL evaluation

### Performance

- **Sequential Processing**: Safe, predictable execution
- **Rate Limiting**: Configurable delays (default: 0.5s)
- **Batch Operations**: Grouped where possible
- **Dry Run Mode**: Test without API calls

### Deployment Modes

| Mode | Behavior | Use Case |
|------|----------|----------|
| `fresh` | Create only if doesn't exist | Initial deployment |
| `update` | Idempotent updates (default) | Regular updates |
| `force` | Delete and recreate | Complete reset |

### Drift Detection

NotionForge can compare deployed workspaces with definitions:

```ruby
# Check for changes
notion_forge check workspace.rb

# Auto-fix discrepancies
notion_forge check workspace.rb --fix
```

Detects:
- Missing/extra resources
- Schema modifications
- Content changes
- Property updates

---

## Best Practices

### 1. Organization

```ruby
# Group related databases
NotionForge::Workspace.new(title: "Company Hub") do
  # --- DATA LAYER ---
  database "Customers" do
    # ...
  end
  
  database "Orders" do
    # ...
  end
  
  # --- DOCUMENTATION ---
  page "Onboarding" do
    # ...
  end
  
  page "FAQ" do
    # ...
  end
end
```

### 2. Naming Conventions

- **Databases**: Plural nouns (`Tasks`, `Projects`, `Contacts`)
- **Properties**: Descriptive (`Due Date`, not `Date`)
- **Pages**: Action-oriented (`Getting Started`, `How to Use`)
- **Relations**: Clear direction (`Assigned To`, `Belongs To`)

### 3. Performance

```ruby
# Configure appropriate rate limiting
NotionForge.configure do |config|
  config.rate_limit = 0.3  # Faster for small workspaces
  config.rate_limit = 1.0  # Safer for large deployments
end
```

### 4. Version Control

Store workspace definitions in Git:

```bash
git add workspaces/crm.rb
git commit -m "Add customer notes field to CRM"
```

### 5. Testing

```bash
# Validate syntax
notion_forge validate workspace.rb

# Visualize structure
notion_forge visualize workspace.rb

# Check for drift
notion_forge check workspace.rb
```

---

## CLI Commands Reference

```bash
# Setup
notion_forge setup                    # Initial configuration
notion_forge status                   # Check configuration

# Deployment
notion_forge forge workspace.rb       # Deploy workspace
notion_forge forge workspace.rb -m fresh   # Only create new
notion_forge forge workspace.rb -m force   # Recreate all

# Validation
notion_forge validate workspace.rb    # Check syntax
notion_forge visualize workspace.rb   # Preview structure
notion_forge check workspace.rb       # Detect drift
notion_forge check workspace.rb --fix # Auto-fix drift

# Templates
notion_forge workspaces               # List available
notion_forge examples                 # Generate examples
```

---

## Troubleshooting

### Common Issues

**Authentication Failed**
```bash
# Recreate configuration
notion_forge setup --force
```

**Rate Limit Errors**
```ruby
# Increase delay in config
config.rate_limit = 1.0
```

**Permission Errors**
- Ensure integration has access to parent page
- Check page sharing settings in Notion

**Schema Validation**
```bash
# Validate before deployment
notion_forge validate workspace.rb
```

---

## API Usage in Your Micro-SaaS

### Integration Pattern

```ruby
# 1. User provides natural language prompt
user_prompt = "Create a task manager with projects and team members"

# 2. AI translates to NotionForge DSL
ai_translator = NotionForge::AITranslator.new(api_key: ENV['OPENAI_API_KEY'])
dsl_code = ai_translator.translate_prompt_to_dsl(user_prompt)

# 3. Preview for user approval
preview = {
  code: dsl_code,
  estimated_resources: count_resources(dsl_code)
}

# 4. Execute after approval
workspace = safe_eval_dsl(dsl_code)
result = workspace.forge!(mode: :update)

# 5. Return deployment summary
{
  workspace_id: workspace.root.id,
  databases_created: result.databases.count,
  pages_created: result.pages.count,
  status: 'success'
}
```

---

## Support & Resources

- **GitHub**: [NotionForge Repository]
- **Documentation**: This guide
- **Examples**: Run `notion_forge examples`
- **API Reference**: https://developers.notion.com/reference

---

*Generated for NotionForge v1.0.0*