# Jira Issue Metadata Guide

This guide explains the metadata fields required when creating Jira issues.

## Required Metadata

### project_key
- **Description**: The Jira project identifier
- **Format**: Project name
- **How to obtain**:
  - Use `mcp__mcp-atlassian__jira_get_all_projects` to list available projects
  - Check the project key from the issue keys (e.g., `VIC-123` → project key is `VIC`)
- **Example**: `VIC`

### summary
- **Description**: The issue title/headline
- **Format**: Clear, concise statement of what the issue is about
- **Best practices**:
  - Keep it under 100 characters
  - Use sentence case
  - Be specific and descriptive
  - Avoid redundant words like "Issue:", "Task:"
- **Examples**:
  - Good: "Self-Hosted LLM Serving Infrastructure"
  - Bad: "Task: Do the LLM thing"

### issue_type
- **Description**: The type of Jira issue being created
- **Common types**:
  - `Epic` - Large body of work that contains multiple stories/tasks
  - `Story` - User-facing feature or functionality
  - `Task` - Technical work or non-user-facing task
  - `Bug` - Defect or error to be fixed
  - `Subtask` - Child task under a parent issue
- **Note**: Available issue types depend on project configuration
- **Example**: `Epic`

## Optional but Recommended Metadata

### assignee
- **Description**: Person responsible for the issue
- **Format**: Atlassian Account ID (recommended) or email address
- **Data Type**: `string`
- **How to obtain Account ID**:
  - From Atlassian profile URL: `https://home.atlassian.com/o/{org-id}/people/{account-id}?cloudId=...`
  - The Account ID is the value after `/people/` (e.g., `712020:bcc95996-28a7-4346-8ad3-cbb480f3cc1d`)
  - From existing issue: Check the `reporter` or `assignee` field which contains `accountId`
- **Examples**:
  - Account ID: `712020:bcc95996-28a7-4346-8ad3-cbb480f3cc1d` (recommended)
  - Email: `yuyu_liao@vicone.com`
- **Note**: If not specified or invalid, issue will be created as "Unassigned". Account ID format is more reliable than email.

### description
- **Description**: Detailed explanation of the issue
- **Format**: Markdown text that will be converted to Jira wiki markup
- **Best practices**:
  - Use the description template (Why/What/Scope/Out of Scope)
  - Include links to related resources
  - Add code examples or diagrams if helpful
- **Note**: This is one of the most important fields for communication

### components
- **Description**: Component(s) within the project
- **Data Type**: `string` (comma-separated for multiple)
- **Parameter**: Direct parameter in `jira_create_issue`
- **Examples**:
  - Single: `"xNexus"`
  - Multiple: `"xNexus,API,Frontend"`
- **How to verify**: Check existing issues in the project to see available components
- **Note**: Components must exist in the project before use

### labels
- **Description**: Tags for categorization and filtering
- **Data Type**: `array of strings`
- **Parameter**: Via `additional_fields`
- **Format**: `{"labels": ["label1", "label2"]}`
- **Examples**:
  - `{"labels": ["AI-Squad"]}`
  - `{"labels": ["infrastructure", "poc", "urgent"]}`
- **Best practices**:
  - Use existing labels when possible
  - Use lowercase with hyphens for multi-word labels (e.g., `tech-debt`)
  - Keep labels short and meaningful

### priority
- **Description**: Importance level of the issue
- **Format**: Priority name (project-specific)
- **Common values**:
  - `High`, `Medium`, `Low`
  - `P1`, `P2`, `P3`, `P4`
- **Note**: Available priorities depend on project configuration

## Advanced Metadata (via additional_fields)

### parent
- **Description**: Parent issue key (for subtasks or linking to Epic)
- **Format**: `{'parent': 'PROJECT-123'}`
- **Use case**: Creating subtasks or child issues

### Epic Link
- **Description**: Link issue to an Epic
- **Note**: Use `parent` field or Epic-specific custom field depending on project setup

### fixVersions
- **Description**: Target release version(s)
- **Format**: `{'fixVersions': [{'id': '10020'}]}`
- **How to obtain**: Use `mcp__mcp-atlassian__jira_get_project_versions` to list versions

### Custom Fields
- **Description**: Project-specific fields
- **Format**: `{'customfield_10010': 'value'}`
- **How to discover**: Use `mcp__mcp-atlassian__jira_search_fields` to find custom field IDs

### sprint
- **Description**: Assign issue to a specific sprint
- **Data Type**: `number` (Sprint ID)
- **Parameter**: Via `additional_fields` using the sprint custom field
- **Custom Field ID**: `customfield_10020` (may vary by Jira instance)
- **Format**: `{"customfield_10020": <sprint_id>}`
- **How to obtain Sprint ID**:
  1. Find the board ID: `mcp__mcp-atlassian__jira_get_agile_boards(project_key="VIC")`
  2. Get sprints from board: `mcp__mcp-atlassian__jira_get_sprints_from_board(board_id="14", state="future")`
  3. Use the `id` field from the sprint object (e.g., `10248`)
- **Example**:
  ```json
  {
    "additional_fields": {
      "customfield_10020": 10248
    }
  }
  ```
- **Sprint States**:
  - `active` - Currently running sprint
  - `future` - Upcoming sprints
  - `closed` - Completed sprints
- **Note**: The sprint custom field ID can be discovered using `mcp__mcp-atlassian__jira_search_fields(keyword="sprint")`

## Metadata Collection Strategy

When creating an issue, follow this collection strategy:

1. **Always ask for**: project_key, issue_type
2. **Usually ask for**: summary, assignee, components
3. **Generate from requirements**: description (using template)
4. **Ask if relevant**: labels, priority, parent
5. **Skip unless needed**: fixVersions, custom fields

## Common Patterns

### Creating an Epic
```
Required: project_key, summary, issue_type="Epic", description
Recommended: assignee, components
```

### Creating a Story
```
Required: project_key, summary, issue_type="Story", description
Recommended: assignee, components, labels, parent (Epic link)
```

### Creating a Bug
```
Required: project_key, summary, issue_type="Bug", description
Recommended: assignee, components, priority="High"
```

### Creating a Task
```
Required: project_key, summary, issue_type="Task", description
Recommended: assignee, components
```

## API Field Formats Quick Reference

| Field | Data Type | Parameter Location | Example |
|-------|-----------|-------------------|---------|
| `project_key` | `string` | Direct param | `"VIC"` |
| `summary` | `string` | Direct param | `"Issue title"` |
| `issue_type` | `string` | Direct param | `"Task"` |
| `assignee` | `string` (Account ID) | Direct param | `"712020:bcc95996-28a7-4346-8ad3-cbb480f3cc1d"` |
| `description` | `string` (Markdown) | Direct param | `"## Why\n..."` |
| `components` | `string` (comma-separated) | Direct param | `"xNexus,API"` |
| `labels` | `array of strings` | `additional_fields` | `{"labels": ["AI-Squad"]}` |
| `parent` | `string` (Issue key) | `additional_fields` | `{"parent": "VIC-123"}` |
| `priority` | `object` | `additional_fields` | `{"priority": {"name": "P1"}}` |
| `sprint` | `number` (Sprint ID) | `additional_fields` | `{"customfield_10020": 10248}` |
| `fixVersions` | `array of objects` | `additional_fields` | `{"fixVersions": [{"id": "10020"}]}` |

### Complete Example with All Fields

```json
{
  "project_key": "VIC",
  "summary": "Compare vLLM and SGLang performance",
  "issue_type": "Task",
  "assignee": "712020:bcc95996-28a7-4346-8ad3-cbb480f3cc1d",
  "description": "## Objective\nBenchmark inference engines...",
  "components": "xNexus",
  "additional_fields": {
    "parent": "VIC-23678",
    "labels": ["AI-Squad", "infrastructure"],
    "customfield_10020": 10248,
    "priority": {"name": "P2"}
  }
}
```
