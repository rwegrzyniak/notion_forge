# NotionForge Validation System

The NotionForge gem includes a comprehensive validation system that helps detect issues in your DSL code before deployment to Notion. This is especially useful for SaaS applications that allow users to create custom Notion workspaces.

## Quick Start

### Basic Validation

```ruby
# Validate DSL code string
dsl_code = File.read('my_workspace.rb')
result = NotionForge::Workspace.validate(dsl_code)

if result[:status] == 'valid'
  puts "✅ DSL is valid!"
else
  puts "❌ Validation failed with #{result[:summary][:total_errors]} errors"
end
```

### SaaS Integration

```ruby
class MyNotionSaaS
  def validate_user_workspace(user_dsl_code)
    result = NotionForge::Workspace.validate(user_dsl_code)
    
    {
      success: result[:status] == 'valid',
      deployable: result[:summary][:total_errors] == 0,
      errors: result[:errors],
      warnings: result[:warnings],
      summary: result[:summary]
    }
  end
end
```

## Validation Response Format

The validation method returns a JSON-serializable hash with the following structure:

```ruby
{
  status: 'valid' | 'invalid',
  has_warnings: true | false,
  errors: [
    {
      type: 'error',
      code: 'error_code',
      message: 'Human readable error message',
      fix: 'Suggested solution',
      line: 15, # Optional line number
      context: { ... } # Additional context
    }
  ],
  warnings: [
    {
      type: 'warning',
      code: 'warning_code', 
      message: 'Human readable warning message',
      fix: 'Suggested improvement',
      line: 20,
      context: { ... }
    }
  ],
  summary: {
    total_errors: 2,
    total_warnings: 1,
    critical_issues: 1,
    validation_type: 'dsl_code'
  }
}
```

## Validation Types

### 1. Syntax Validation
Checks for Ruby syntax errors in the DSL code.

**Common Issues:**
- Missing `end` statements
- Syntax errors in method calls
- Invalid Ruby code structure

**Example Error:**
```ruby
{
  code: 'syntax_error',
  message: 'DSL syntax error: unexpected end of file',
  fix: 'Fix Ruby syntax errors in the DSL code',
  line: 15
}
```

### 2. DSL Structure Validation
Ensures the DSL follows NotionForge conventions.

**Checks:**
- Required `forge_workspace` method definition
- Proper `NotionForge::Workspace.new` usage
- Block structure validation

**Example Error:**
```ruby
{
  code: 'missing_forge_method',
  message: 'DSL must define a forge_workspace method',
  fix: 'Wrap your workspace definition in: def forge_workspace ... end'
}
```

### 3. Property Usage Validation
Validates property definitions and usage patterns.

**Checks:**
- Status properties with options (warns about API issues)
- URL properties requiring `to_notion_url` method
- Empty option arrays
- Duplicate property names

**Example Warning:**
```ruby
{
  code: 'status_property_issue',
  message: 'Status properties with options may cause API validation errors',
  fix: 'Use select properties instead: select "Status", options: [...]'
}
```

### 4. Method Availability Validation
Checks if required methods are available in the current gem version.

**Checks:**
- `to_notion_url` method on String class
- `status_property` method availability
- Other version-specific methods

**Example Error:**
```ruby
{
  code: 'missing_method_to_notion_url',
  message: "Required method 'to_notion_url' is not available on String",
  fix: 'Use plain strings instead of URL objects',
  context: {
    method: 'to_notion_url',
    target_class: 'String',
    introduced_in: '1.2.0',
    description: 'Convert strings to Notion-compatible URLs'
  }
}
```

### 5. API Compatibility Validation
Validates against Notion API limits and requirements.

**Checks:**
- Authentication configuration
- Database and page count limits
- Property count limits per database
- Supported property types

**Example Warning:**
```ruby
{
  code: 'too_many_databases',
  message: 'Workspace contains 150 databases, which may hit API limits (recommended: < 100)',
  fix: 'Consider splitting into multiple workspaces'
}
```

## Command Line Usage

```bash
# Basic validation
notion_forge validate my_workspace.rb

# JSON output for programmatic usage
notion_forge validate --json my_workspace.rb

# Strict mode (treat warnings as errors)
notion_forge validate --strict my_workspace.rb

# Save results to file
notion_forge validate --output results.json my_workspace.rb
```

## Common Validation Scenarios

### 1. Valid DSL Example
```ruby
def forge_workspace
  NotionForge::Workspace.new(title: "My Workspace") do
    projects = database "Projects" do
      title
      select "Status", options: ["Active", "Complete"]
      date "Due Date"
      text "Description"
    end
    
    page "Documentation" do
      # Page content
    end
  end
end
```
**Result:** `status: 'valid'` (may have method warnings depending on gem version)

### 2. Syntax Error Example
```ruby
def forge_workspace
  NotionForge::Workspace.new(title: "My Workspace") do
    database "Projects" do
      title
      select "Status" options: ["Active"] # Missing comma
    # Missing end
  end
end
```
**Result:** `status: 'invalid'` with syntax error

### 3. Status Property Warning Example
```ruby
def forge_workspace
  NotionForge::Workspace.new(title: "My Workspace") do
    database "Tasks" do
      title
      status options: [
        { name: "Todo", color: "gray" },
        { name: "Done", color: "green" }
      ]
    end
  end
end
```
**Result:** Warning about status property usage

## Integration with CI/CD

```yaml
# GitHub Actions example
name: Validate NotionForge DSL
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.3.0
      - run: bundle install
      - run: notion_forge validate --strict workspace.rb
```

## Error Codes Reference

| Code | Type | Description |
|------|------|-------------|
| `syntax_error` | Error | Ruby syntax errors in DSL |
| `missing_forge_method` | Error | No `forge_workspace` method defined |
| `missing_workspace_init` | Error | No `NotionForge::Workspace.new` call |
| `missing_method_*` | Error | Required method not available |
| `url_property_unsupported` | Error | URL property without `to_notion_url` |
| `undefined_relation_reference` | Error | Relation to undefined database |
| `status_property_issue` | Warning | Status property may cause API issues |
| `empty_options` | Warning | Property with empty options array |
| `duplicate_property` | Warning | Duplicate property names in database |
| `too_many_databases` | Warning | Database count exceeds recommendations |
| `too_many_properties` | Warning | Property count exceeds recommendations |
| `missing_auth_token` | Error | No Notion API token configured |

## Best Practices

1. **Always validate before deployment** - Use validation in your deployment pipeline
2. **Handle warnings appropriately** - Some warnings are just recommendations
3. **Use strict mode in CI** - Treat warnings as errors in automated environments
4. **Provide user feedback** - Show validation results to users in your SaaS
5. **Cache validation results** - Avoid re-validating unchanged DSL code
6. **Log validation events** - Track validation failures for debugging

## Extending Validation

You can create custom validators by extending the base validator:

```ruby
class CustomValidator < NotionForge::Validation::BaseValidator
  def validate
    # Your custom validation logic
    if some_condition
      add_error('custom_error', 'Custom error message', fix: 'How to fix it')
    end
  end
end
```

## API Reference

### `NotionForge::Workspace.validate(dsl_code)`
Main validation method for DSL code strings.

**Parameters:**
- `dsl_code` (String): The DSL code to validate

**Returns:** Hash with validation results

### `workspace.validate_before_deploy`
Validates an existing workspace instance before deployment.

**Returns:** Validator instance with results

### `workspace.valid_for_deployment?`
Quick check if workspace is valid for deployment.

**Returns:** Boolean
