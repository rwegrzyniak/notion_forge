# Development Guide

## Setup

1. **Install Ruby 3.3+**
   ```bash
   # Using RVM
   rvm install 3.3.0
   rvm use 3.3.0
   rvm gemset create notion_forge
   rvm use 3.3.0@notion_forge
   
   # Or using rbenv
   rbenv install 3.3.0
   rbenv local 3.3.0
   ```

2. **Clone and setup**
   ```bash
   git clone git@github.com:johnny/notion_forge.git
   cd notion_forge
   bin/setup
   ```

## Development Workflow

### Running Tests
```bash
# Run all tests
rake test

# Run tests in parallel (faster!)
rake test TESTOPTS="--parallel"

# Run specific test file
ruby -Itest test/notion_forge_test.rb

# Run with coverage
COVERAGE=true rake test
```

### Code Quality
```bash
# Run RuboCop
rake rubocop

# Auto-fix issues
rake fix

# Run all checks (tests + rubocop)
rake check
```

### Documentation
```bash
# Generate docs
rake docs

# View docs
open doc/index.html
```

### Console
```bash
# Start console with gem loaded
rake console

# Quick test
irb -Ilib -rnotion_forge
```

## Modern Ruby Features Used

### Pattern Matching (Ruby 3.0+)
```ruby
case workspace
in { databases: [db, *rest] } if db.title == "Tasks"
  puts "Found Tasks database!"
in { pages: [] }
  puts "No pages found!"
else
  puts "Unknown workspace structure"
end
```

### Endless Methods (Ruby 3.0+)
```ruby
def name = title
def persisted? = !id.nil?
def mode_emoji(mode) = mode == :fresh ? "🆕" : "🔄"
```

### Rightward Assignment (Ruby 3.0+)
```ruby
workspace.databases.first => { title:, properties: }
puts "Database: #{title}"
```

### Anonymous Block Forwarding (Ruby 3.1+)
```ruby
def configure(&) = yield(configuration)
def build(&) = PageBuilder.new(self).instance_eval(&) if block_given?
```

### Data Class (Ruby 3.2+)
```ruby
# Could be used for immutable configuration
ResourceMetadata = Data.define(:name, :created_at, :type)
```

## Architecture

```
lib/
├── notion_forge.rb              # Main entry point
├── notion_forge/
│   ├── version.rb              # Version constant
│   ├── configuration.rb        # Configuration management
│   ├── errors.rb               # Custom exceptions
│   ├── refinements.rb          # String/Hash/Array extensions
│   ├── cli.rb                  # Thor CLI interface
│   ├── client.rb               # HTTP client (Notion API)
│   ├── state_manager.rb        # State persistence
│   ├── resource.rb             # Base resource class
│   ├── page.rb                 # Page resource
│   ├── database.rb             # Database resource
│   ├── template.rb             # Template resource
│   ├── workspace.rb            # Main workspace builder
│   ├── property.rb             # Property type builders
│   ├── block.rb                # Content block builders
│   ├── builders/               # DSL builders
│   ├── parallel_executor.rb    # Ractor-based parallelism
│   ├── fiber_pool.rb           # Fiber management
│   ├── query_builder.rb        # Resource queries
│   ├── resource_collection.rb  # Collection utilities
│   └── dsl.rb                  # Top-level DSL
```

## Testing Strategy

- **Unit Tests**: Test individual classes and methods
- **Integration Tests**: Test CLI commands and full workflows  
- **Parallel Execution**: Minitest's built-in parallelization
- **Mocking**: WebMock for HTTP requests
- **VCR**: Record real API interactions for testing

## Contributing

1. Fork the repo
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass: `rake check`
5. Submit a pull request

## Release Process

1. Update version in `lib/notion_forge/version.rb`
2. Update `CHANGELOG.md`
3. Commit with message `[release] v0.x.x`
4. Push to main branch
5. GitHub Actions will automatically build and publish the gem
