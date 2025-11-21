# Editor Integration Guide for NotionForge Validation

This guide explains how to integrate NotionForge validation with code editors and IDEs to provide real-time feedback to users writing DSL code.

## Overview

The NotionForge validation system now provides precise line numbers for all validation issues, making it perfect for editor integration with features like:

- ✅ **Real-time error highlighting** - Show errors as users type
- ✅ **Hover tooltips** - Display error messages and fixes on hover
- ✅ **Problems panel** - List all issues in a dedicated panel
- ✅ **Quick fixes** - Suggest automatic fixes for common issues
- ✅ **Syntax highlighting** - Mark problematic lines with colors

## API Response Format

The validation API returns issues with precise line numbers:

```json
{
  "status": "invalid",
  "has_warnings": true,
  "errors": [
    {
      "type": "error",
      "code": "missing_database_title",
      "message": "Database definitions require a title parameter",
      "fix": "Use: database \"Database Name\" do ... end",
      "line": 25,
      "context": {}
    }
  ],
  "warnings": [
    {
      "type": "warning", 
      "code": "status_property_issue",
      "message": "Status properties with options may cause API validation errors",
      "fix": "Use select properties instead: select \"Status\", options: [...]",
      "line": 17,
      "context": {}
    }
  ],
  "summary": {
    "total_errors": 1,
    "total_warnings": 1,
    "critical_issues": 1,
    "validation_type": "dsl_code"
  }
}
```

## VS Code Extension Integration

### Basic Setup

```typescript
import * as vscode from 'vscode';

export class NotionForgeValidator {
  private diagnosticCollection: vscode.DiagnosticCollection;

  constructor() {
    this.diagnosticCollection = vscode.languages.createDiagnosticCollection('notionforge');
  }

  async validateDocument(document: vscode.TextDocument) {
    if (!document.fileName.endsWith('.rb')) return;
    
    const dslCode = document.getText();
    const result = await this.callValidationAPI(dslCode);
    
    this.updateDiagnostics(document, result);
  }

  private async callValidationAPI(dslCode: string) {
    // Call your SaaS validation endpoint or run NotionForge locally
    const response = await fetch('/api/validate-notionforge', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ dsl_code: dslCode })
    });
    
    return await response.json();
  }

  private updateDiagnostics(document: vscode.TextDocument, result: any) {
    const diagnostics: vscode.Diagnostic[] = [];
    
    // Process errors and warnings
    [...(result.errors || []), ...(result.warnings || [])].forEach(issue => {
      const line = Math.max(0, (issue.line || 1) - 1); // Convert to 0-based
      const range = new vscode.Range(line, 0, line, 999);
      
      const diagnostic = new vscode.Diagnostic(
        range,
        issue.message,
        issue.type === 'error' 
          ? vscode.DiagnosticSeverity.Error 
          : vscode.DiagnosticSeverity.Warning
      );
      
      diagnostic.code = issue.code;
      diagnostic.source = 'notionforge';
      
      // Add fix suggestion if available
      if (issue.fix) {
        diagnostic.relatedInformation = [
          new vscode.DiagnosticRelatedInformation(
            new vscode.Location(document.uri, range),
            `Fix: ${issue.fix}`
          )
        ];
      }
      
      diagnostics.push(diagnostic);
    });
    
    this.diagnosticCollection.set(document.uri, diagnostics);
  }
}
```

### Code Actions (Quick Fixes)

```typescript
export class NotionForgeCodeActionProvider implements vscode.CodeActionProvider {
  provideCodeActions(
    document: vscode.TextDocument,
    range: vscode.Range,
    context: vscode.CodeActionContext
  ): vscode.CodeAction[] {
    const actions: vscode.CodeAction[] = [];
    
    context.diagnostics
      .filter(d => d.source === 'notionforge')
      .forEach(diagnostic => {
        // Example: Fix missing database title
        if (diagnostic.code === 'missing_database_title') {
          const action = new vscode.CodeAction(
            'Add database title',
            vscode.CodeActionKind.QuickFix
          );
          
          action.edit = new vscode.WorkspaceEdit();
          const line = document.lineAt(diagnostic.range.start.line);
          const newText = line.text.replace(/database\s+do/, 'database "My Database" do');
          
          action.edit.replace(
            document.uri,
            line.range,
            newText
          );
          
          actions.push(action);
        }
        
        // Example: Convert status to select
        if (diagnostic.code === 'status_property_issue') {
          const action = new vscode.CodeAction(
            'Convert status to select property',
            vscode.CodeActionKind.QuickFix
          );
          
          action.edit = new vscode.WorkspaceEdit();
          const line = document.lineAt(diagnostic.range.start.line);
          const newText = line.text.replace(/\bstatus\b/, 'select');
          
          action.edit.replace(document.uri, line.range, newText);
          actions.push(action);
        }
      });
    
    return actions;
  }
}
```

## Language Server Protocol (LSP) Integration

For editors that support LSP, you can create a dedicated language server:

```typescript
// NotionForge Language Server
import {
  createConnection,
  TextDocuments,
  ProposedFeatures,
  InitializeParams,
  DidChangeConfigurationNotification,
  CompletionItem,
  CompletionItemKind,
  TextDocumentPositionParams,
  TextDocumentSyncKind,
  InitializeResult,
  Diagnostic,
  DiagnosticSeverity
} from 'vscode-languageserver/node';

const connection = createConnection(ProposedFeatures.all);
const documents: TextDocuments<TextDocument> = new TextDocuments(TextDocument);

documents.onDidChangeContent(change => {
  validateTextDocument(change.document);
});

async function validateTextDocument(textDocument: TextDocument): Promise<void> {
  const text = textDocument.getText();
  const result = await validateNotionForgeDSL(text);
  
  const diagnostics: Diagnostic[] = [];
  
  [...(result.errors || []), ...(result.warnings || [])].forEach(issue => {
    const line = Math.max(0, (issue.line || 1) - 1);
    
    const diagnostic: Diagnostic = {
      severity: issue.type === 'error' 
        ? DiagnosticSeverity.Error 
        : DiagnosticSeverity.Warning,
      range: {
        start: { line, character: 0 },
        end: { line, character: 999 }
      },
      message: issue.message,
      code: issue.code,
      source: 'notionforge',
      codeDescription: {
        href: `https://docs.notionforge.dev/validation/${issue.code}`
      },
      data: {
        fix: issue.fix,
        context: issue.context
      }
    };
    
    diagnostics.push(diagnostic);
  });
  
  connection.sendDiagnostics({ uri: textDocument.uri, diagnostics });
}
```

## Web Editor Integration (Monaco Editor)

For web-based editors like Monaco (used in VS Code online):

```javascript
// Monaco Editor Integration
import * as monaco from 'monaco-editor';

class NotionForgeValidator {
  constructor(editor) {
    this.editor = editor;
    this.model = editor.getModel();
    
    // Validate on content changes
    this.model.onDidChangeContent(() => {
      this.debounceValidation();
    });
  }
  
  debounceValidation = this.debounce(this.validate.bind(this), 500);
  
  async validate() {
    const dslCode = this.model.getValue();
    const result = await this.callValidationAPI(dslCode);
    
    this.updateMarkers(result);
  }
  
  updateMarkers(result) {
    const markers = [];
    
    [...(result.errors || []), ...(result.warnings || [])].forEach(issue => {
      const line = Math.max(1, issue.line || 1);
      
      markers.push({
        startLineNumber: line,
        startColumn: 1,
        endLineNumber: line,
        endColumn: 999,
        message: issue.message,
        severity: issue.type === 'error' 
          ? monaco.MarkerSeverity.Error 
          : monaco.MarkerSeverity.Warning,
        code: issue.code,
        source: 'notionforge'
      });
    });
    
    monaco.editor.setModelMarkers(this.model, 'notionforge', markers);
  }
  
  debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  }
}

// Usage
const editor = monaco.editor.create(document.getElementById('editor'), {
  value: 'def forge_workspace\\n  # Your DSL here\\nend',
  language: 'ruby'
});

const validator = new NotionForgeValidator(editor);
```

## Syntax Highlighting

Enhance the Ruby syntax highlighting to recognize NotionForge DSL keywords:

```json
{
  "scopeName": "source.ruby.notionforge",
  "patterns": [
    {
      "match": "\\b(forge_workspace|database|page|template)\\b",
      "name": "keyword.control.notionforge"
    },
    {
      "match": "\\b(title|text|select|status|date|number|email|phone|url|checkbox|created_time|multi_select)\\b",
      "name": "support.function.property.notionforge"
    },
    {
      "match": "\\b(relate|rollup|formula)\\b", 
      "name": "support.function.relation.notionforge"
    },
    {
      "match": "\\b(section|callout|todo|quote|code|expandable|hr)\\b",
      "name": "support.function.block.notionforge"  
    }
  ]
}
```

## Error Code Documentation

Create documentation URLs for each error code that editors can link to:

- `https://docs.notionforge.dev/validation/syntax_error`
- `https://docs.notionforge.dev/validation/missing_forge_method`
- `https://docs.notionforge.dev/validation/status_property_issue`
- `https://docs.notionforge.dev/validation/duplicate_property`
- etc.

## Testing Editor Integration

```ruby
# Test file: test_editor_integration.rb
require_relative 'lib/notion_forge'

test_cases = [
  {
    name: "Line 5 Error",
    dsl: <<~DSL
      def forge_workspace
        NotionForge::Workspace.new(title: "Test") do
          # This should show error on line 5
          database do
            title
          end
        end
      end
    DSL
  }
]

test_cases.each do |test|
  result = NotionForge::Workspace.validate(test[:dsl])
  
  puts "#{test[:name]}:"
  result[:errors].each do |error|
    puts "  Line #{error[:line]}: #{error[:message]}"
  end
end
```

## Production Considerations

1. **Performance**: Debounce validation calls to avoid overwhelming the server
2. **Caching**: Cache validation results for unchanged content
3. **Error Handling**: Gracefully handle validation API failures
4. **Rate Limiting**: Implement client-side rate limiting for validation requests
5. **Offline Support**: Consider local validation for basic syntax checks

## Integration Checklist

- ✅ Real-time validation with debouncing
- ✅ Line-precise error highlighting
- ✅ Hover tooltips with fix suggestions
- ✅ Problems panel integration
- ✅ Quick fix code actions
- ✅ Enhanced syntax highlighting
- ✅ Documentation links for error codes
- ✅ Graceful error handling
- ✅ Performance optimization

The NotionForge validation system is now fully equipped for professional editor integration with precise line number tracking and comprehensive error reporting!
