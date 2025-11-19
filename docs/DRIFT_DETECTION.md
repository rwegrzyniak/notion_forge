# Drift Detection & Workspace Validation

NotionForge now includes powerful drift detection capabilities to ensure your deployed Notion workspaces match their definitions.

## Features

### 🔍 **Comprehensive Analysis**
- **Resource Existence**: Detects missing/extra databases and pages
- **Schema Validation**: Compares database properties, types, and options  
- **Content Structure**: Analyzes page content and block structure
- **Metadata Checking**: Validates icons, covers, and other properties

### 📊 **Multiple Output Formats**
- **Summary** (default): Quick overview with issue highlights
- **Detailed**: In-depth analysis of each resource
- **JSON**: Machine-readable output for CI/CD integration

### 🔧 **Auto-fix Capability**
- Automatically redeploy resources to resolve drift
- Safe, rate-limited API operations
- Maintains workspace integrity

## Usage

### Basic Drift Check
```bash
notion_forge check workspace.rb
```

### Detailed Analysis
```bash
notion_forge check workspace.rb --detailed
```

### Auto-fix Issues
```bash
notion_forge check workspace.rb --fix
```

### JSON Output (for CI/CD)
```bash
notion_forge check workspace.rb --format=json
```

### Fast Schema-only Check
```bash
notion_forge check workspace.rb --ignore-content
```

## Example Output

### Summary Format
```
❌ Workspace Status: DRIFT DETECTED

📊 Summary:
   • Root page: ✅ Exists
   • Databases: 3 expected, 1 missing
   • Pages: 2 expected, 0 missing
   • Issues found: 3

🔍 Issues Found:
   📭 Missing Resources:
     • Database: Projects
   🔧 Schema Differences:
     • Tasks: Missing property 'Priority'
   📝 Content Changes:
     • Dashboard: Content blocks: expected 5, got 3
```

### Detailed Format
```
🔍 Detailed Workspace Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🏛️ Root Page Analysis:
   title: ✅ ok - Matches
   icon: ❌ mismatch - Expected '🏠', got '🏛️'

📊 Database Analysis:
   Database: Tasks
     ✅ Exists in Notion
     🔧 Schema differences:
       • Priority: Missing property
     ✅ Relations match

📄 Page Analysis:
   Page: Dashboard
     ✅ Exists in Notion
     📝 Content differences:
       • Content blocks: heading_1: expected 2, got 1
```

### JSON Format
```json
{
  "summary": {
    "root_status": "✅ Exists",
    "database_summary": "3 expected, 1 missing", 
    "page_summary": "2 expected, 0 missing",
    "total_issues": 3,
    "has_issues": true
  },
  "issues": {
    "missing_resources": [
      {"type": "Database", "name": "Projects"}
    ],
    "schema_mismatches": [
      {"database": "Tasks", "issue": "Priority: Missing property"}
    ],
    "content_differences": []
  },
  "details": {
    "root_differences": [
      {"property": "icon", "status": "mismatch", "details": "Expected '🏠', got '🏛️'"}
    ],
    "database_details": {...},
    "page_details": {...}
  }
}
```

## Use Cases

### 🚀 **Deployment Validation**
Verify deployments completed successfully:
```bash
notion_forge forge workspace.rb
notion_forge check workspace.rb  # Exit code 0 = success, 1 = drift detected
```

### 🔄 **CI/CD Integration**
```yaml
- name: Deploy Notion Workspace
  run: notion_forge forge production_workspace.rb

- name: Validate Deployment  
  run: |
    notion_forge check production_workspace.rb --format=json > drift_report.json
    # Process drift_report.json for alerts/notifications
```

### 🕵️ **Manual Change Detection**
Detect when team members manually modify Notion:
```bash
# Daily drift check
notion_forge check workspace.rb --detailed
```

### 🛠️ **Infrastructure Compliance**
Ensure workspaces stay compliant with organizational standards:
```bash
# Auto-remediate drift
notion_forge check workspace.rb --fix
```

### ⚡ **Quick Schema Validation**
Fast validation for database schema changes:
```bash
notion_forge check workspace.rb --ignore-content  # Skip content analysis
```

## Exit Codes

- **0**: No drift detected - workspace is in sync
- **1**: Drift detected - issues found that need attention

Perfect for scripting and automation!

## Integration with Other Commands

The drift checker integrates seamlessly with existing NotionForge commands:

```bash
# Full workflow
notion_forge workspaces                    # List available templates  
notion_forge visualize workspace.rb        # Preview structure
notion_forge forge workspace.rb            # Deploy workspace
notion_forge check workspace.rb            # Validate deployment
notion_forge check workspace.rb --fix      # Fix any drift
```

## Performance

- **Fast**: Only fetches necessary data from Notion API
- **Rate Limited**: Respects API limits with built-in delays  
- **Cached**: Uses state management for optimal performance
- **Selective**: `--ignore-content` skips heavy content analysis

## Error Handling

The drift checker gracefully handles:
- Network connectivity issues
- API rate limiting
- Invalid resource IDs
- Permission errors
- Malformed workspace definitions

All errors are clearly reported with actionable suggestions.
