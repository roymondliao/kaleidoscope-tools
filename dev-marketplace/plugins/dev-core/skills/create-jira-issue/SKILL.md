---
name: create-jira-issue
description: This skill should be used when the user requests to create a Jira issue, ticket, Epic, Story, Task, SubTask or Bug. It guides through a systematic process of gathering requirements, drafting content with structured descriptions, collecting necessary metadata, and creating the issue using MCP Atlassian tools.
---

# Create Jira Issue

## Overview

This skill provides a systematic workflow for creating well-structured Jira issues. It handles the complete process from understanding requirements to creating and verifying the issue in Jira, ensuring all necessary metadata is collected and the description follows best practices.

## When to Use This Skill

Use this skill when the user:
- Requests to "create a Jira issue/ticket/Epic/Story/Task/SubTask/Bug"
- Says "open a new ticket" or "create an issue in [project]"
- Describes work that needs to be tracked in Jira
- Asks to document a feature, bug, or task in the issue tracker

## Workflow

Follow these steps in order to create a Jira issue:

### Step 1: Requirements Gathering and Research

Understand what the user wants to create and collect initial information.

**Actions:**
1. Ask about the nature of the work to be done
2. Identify the issue type (Epic, Story, Task, Bug, etc.)
3. Understand the context and requirements
4. If helpful, check whether web research tools are available (e.g., `search_web`, `read_url_content`). If available and needed, perform a web search and read relevant sources.

**Collect metadata during this phase:**
- `project_key` - Which Jira project? (e.g., "VIC board" → project_key: `VIC`)
- `issue_type` - What type of issue? (Epic, Story, Task, Bug)
- `assignee` - Who will work on this?
- `components` - Which component(s) does this relate to?
- `labels` - Any relevant tags? (will be passed via `additional_fields.labels` as a list of strings)

**Note on metadata collection:**
- User requests often contain implicit metadata (e.g., "open an Epic in VIC" provides both issue_type and project_key)
- Extract what's provided and only ask for missing required fields
- See `references/metadata-guide.md` for detailed metadata information

### Step 2: Draft Issue Content

Create a well-structured description following the standard template.

**Structure to follow:**
```markdown
### Why
- List the motivations and value propositions
- Business value, user impact, strategic alignment
- Problem being solved

### What
Brief description of what will be built or changed.

**Tech Stack** (if applicable):
- Key technologies/frameworks
- Relevant versions or configurations

### Scope
- Specific deliverables
- Features to implement
- Testing and documentation
- Measurements or benchmarks

**Success Criteria**:
- [ ] Measurable outcome 1
- [ ] Measurable outcome 2
- [ ] Measurable outcome 3

### Out of Scope
- What is NOT included
- Deferred features
- Clarifications to prevent scope creep
```

**Adapt the template based on issue type:**
- **Epics**: Use all sections comprehensively
- **Stories**: Focus on Why, What, and Success Criteria
- **Tasks**: May only need What and Scope
- **Bugs**: Replace "Why" with "Problem Description", "What" with "Root Cause"

**Reference:** See `references/description-template.md` for detailed template guidance and examples.

### Step 3: User Review

Present the draft to the user for review before creating the issue.

**What to present:**
1. Issue summary (title)
2. Full description (Why/What/Scope/Out of Scope)
3. All metadata that will be used (project_key, issue_type, assignee, components, labels, etc.)

**Ask:** "Please review this content. Should I proceed with creating the issue, or would you like any changes?"

**Handle feedback:**
- If user requests changes, update the draft and present again
- If user approves, proceed to Step 4

### Step 4: Create the Issue

Use MCP Atlassian tools to create the issue in Jira.

**Tool:** `mcp__mcp-atlassian__jira_create_issue`

**Required parameters:**
- `project_key` - Project identifier (e.g., `VIC`)
- `summary` - Issue title
- `issue_type` - Type of issue (e.g., `Epic`, `Story`, `Task`, `Bug`)

**Optional parameters:**
- `assignee` - Person responsible
- `description` - Full description using markdown (will be converted to Jira format)
- `components` - Component name(s), comma-separated
- `additional_fields` - Dictionary for priority, labels, parent, etc.

**Example call:**
```text
mcp__mcp-atlassian__jira_create_issue
{
  "project_key": "VIC",
  "summary": "Self-Hosted LLM Serving Infrastructure",
  "issue_type": "Epic",
  "assignee": "yuyu_liao",
  "description": "## Why\n- Reduce costs...",
  "components": "xNexus",
  "additional_fields": {
    "labels": ["infrastructure", "poc"]
  }
}
```

### Step 5: Verify and Report Results

After creation, verify the issue was created successfully and report back to the user.

**Verification approach:**
- The `jira_create_issue` response includes the created issue details
- Check the response for successful creation
- Extract the issue key, URL, and other relevant information

**Optional additional verification:**
If any fields need explicit verification (e.g., assignee status), use:
```text
mcp__mcp-atlassian__jira_get_issue
{
  "issue_key": "VIC-12345",
  "fields": "assignee,components,status"
}
```

**Report to user:**
Present the following information:
1. **Issue Key** (e.g., VIC-12345)
2. **Issue URL** (direct link to view in Jira)
3. **Key fields confirmation:**
   - Status
   - Issue Type
   - Assignee
   - Components
   - Any other relevant metadata
4. **Note any issues** (e.g., if assignee couldn't be set, inform user they may need to set it manually)

**Example output format:**
```
✅ Issue created successfully!

**Issue Details:**
- Issue Key: VIC-12345
- URL: https://yourorg.atlassian.net/browse/VIC-12345
- Status: TO DO
- Issue Type: Epic
- Components: xNexus ✓
- Assignee: [Status]

[Any additional notes or warnings]
```

## Best Practices

1. **Always collect metadata early**: Ask for project_key, issue_type, and other metadata during Step 1 to avoid back-and-forth

2. **Extract implicit information**: Users often provide metadata in their request (e.g., "create an Epic in VIC" → issue_type=Epic, project_key=VIC)

3. **Use the description template**: Structured descriptions improve communication and tracking

4. **Adapt to issue type**: Not all sections are needed for every issue type (Tasks may be simpler than Epics)

5. **Always get user approval**: Never create an issue without user review of the content

6. **Provide clear feedback**: After creation, give the user all the information they need to find and work with the issue

7. **Handle errors gracefully**: If creation fails or fields can't be set (like assignee), inform the user clearly and provide guidance

## MCP Tools Reference

This skill uses the following MCP Atlassian tools:

### For project discovery:
- `mcp__mcp-atlassian__jira_get_all_projects` - List available projects

### For creation:
- `mcp__mcp-atlassian__jira_create_issue` - Create the issue

### For verification (optional):
- `mcp__mcp-atlassian__jira_get_issue` - Verify issue details

### For metadata discovery:
- `mcp__mcp-atlassian__jira_search_fields` - Find custom field IDs
- `mcp__mcp-atlassian__jira_get_project_versions` - List fix versions

## Resources

### references/description-template.md
Detailed template and guidelines for creating well-structured issue descriptions. Includes examples and best practices for different issue types.

### references/metadata-guide.md
Comprehensive guide to Jira metadata fields including required vs. optional fields, formats, examples, and collection strategies.
