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
- **Format**: Can be email, username, or account ID
- **Examples**:
  - `yuyu_liao`
  - `yuyu_liao@vicone.com`
  - `accountid:5f8a9b1c2d3e4f5g6h7i8j9k`
- **Note**: If not specified or invalid, issue will be created as "Unassigned"

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
- **Format**: Comma-separated component names
- **Examples**:
  - `xNexus`
  - `Frontend,API`
- **How to verify**: Check existing issues in the project to see available components
- **Note**: Components must exist in the project before use

### labels
- **Description**: Tags for categorization and filtering
- **Format**: List of label strings provided via `additional_fields` (e.g., `{'labels': ['frontend', 'urgent']}`)
- **Examples**:
  - `['infrastructure', 'poc']`
  - `['frontend', 'urgent']`
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
