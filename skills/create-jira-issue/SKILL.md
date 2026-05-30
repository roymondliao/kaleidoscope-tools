---
name: create-jira-issue
description: This skill should be used when the user requests to create a Jira issue, ticket, Epic, Story, Task, SubTask or Bug. It guides through a systematic process of gathering requirements, drafting content with structured descriptions, collecting necessary metadata, and creating the issue using MCP Atlassian tools.
allowed-tools:
- "mcp__mcp-atlassian__jira_search"
- "mcp__mcp-atlassian__jira_get_issue"
- "mcp__mcp-atlassian__jira_get_project_issues"
- "mcp__mcp-atlassian__jira_get_user_profile"
- "mcp__mcp-atlassian__jira_create_issue"
- "mcp__mcp-atlassian__jira_batch_create_issues"
- "mcp__mcp-atlassian__jira_get_sprint_issues"
- "mcp__mcp-atlassian__jira_get_board_issues"
- "mcp__mcp-atlassian__jira_add_comment"
- "mcp__mcp-atlassian__jira_create_issue_link"
- "mcp__mcp-atlassian__jira_link_to_epic"
- "mcp__mcp-atlassian__jira_update_issue"
- "mcp__mcp-atlassian__confluence_search_user"
user-invocable: true
disable-model-invocation: true
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

### Step 0: Load Configuration Defaults

Before doing anything else, read the `config.yaml` file located in the same directory as this skill (`<skill-dir>/config.yaml`). Parse it as YAML and use its values as **default metadata** throughout the workflow.

**Expected fields in config.yaml:**
```yaml
Project: <project_key>           # → project_key default
Assignee: <assignee_name>    # → assignee default (display name, will be resolved to account ID later)
Components: <component_name>     # → components default
Labels: <label_name>       # → labels default (single value or list)
```

**Rules for using config values:**
- Treat every field in config as a **pre-filled default**, not a hard-coded value
- Fields present in config: use the value, but still show it to the user in the review step so they can override it
- Fields absent from config: always ask the user explicitly
- Dynamic context-dependent fields (`issue_type`, `summary`, `parent`) are **never** stored in config — always gather them from context or ask

**If config.yaml is missing or unreadable:** proceed without defaults and collect all metadata from the user normally.

### Step 1: Requirements Gathering and Research

Understand what the user wants to create and collect initial information.

**Actions:**
1. Ask about the nature of the work to be done
2. Identify the issue type (Epic, Story, Task, Bug, etc.)
3. Understand the context and requirements
4. If helpful, check whether web research tools are available (e.g., `search_web`, `read_url_content`). If available and needed, perform a web search and read relevant sources.

**Collect metadata during this phase:**
- `project_key` - Which Jira project? (e.g., "<project_key> board" → project_key: `<project_key>`)
- `issue_type` - What type of issue? (Epic, Story, Task, Bug)
- `assignee` - Who will work on this?
- `components` - Which component(s) does this relate to?
- `labels` - Any relevant tags? (will be passed via `additional_fields.labels` as a list of strings)

**Note on metadata collection:**
- User requests often contain implicit metadata (e.g., "open an Epic in <project_key>" provides both issue_type and project_key)
- Extract what's provided and only ask for missing required fields
- See `references/metadata-guide.md` for detailed metadata information

### Step 2: Draft Issue Content

Create a well-structured description following the standard template.

**IMPORTANT: Use English for all content** - Write both the issue summary (title) and description in English for consistency and cross-team collaboration, regardless of the language used by the user.

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
3. All metadata that will be used — clearly indicate which values came from `config.yaml` (e.g., mark them with `(from config)`) so the user knows what was auto-filled and can spot anything to override

**Use AskUserQuestion tool for approval:**
After presenting the draft content, use the AskUserQuestion tool to get user decision:

```json
{
  "questions": [
    {
      "question": "Please review the draft above. How would you like to proceed?",
      "header": "Review",
      "options": [
        {
          "label": "Approved, create issue",
          "description": "Create the issue with the content shown above"
        },
        {
          "label": "Need changes",
          "description": "I want to modify some parts before creating"
        },
        {
          "label": "Cancel",
          "description": "Do not create this issue"
        }
      ],
      "multiSelect": false
    }
  ]
}
```

**Handle responses:**
- **Approved, create issue**: Proceed to Step 4 (Collect and Validate Metadata)
- **Need changes**: Ask what needs to be modified, update draft, and present again
- **Cancel**: Acknowledge and end the workflow

### Step 4: Collect and Validate Metadata

Before creating the issue, finalize all required metadata. Use config defaults where available — only ask the user for fields that are missing or that are inherently context-dependent.

**Field resolution priority (highest → lowest):**
1. Explicitly stated in the user's request (e.g., "assign to Alice")
2. Loaded from `config.yaml` in Step 0
3. Ask the user

**Fields that always require asking (never stored in config):**
- `issue_type` — depends on the nature of the work (Epic, Story, Task, Bug, Subtask)
- `summary` — the issue title, always derived from context
- `parent` — for Subtasks/child issues, depends on context

**Fields that use config defaults (ask only if absent from config):**
- `project_key`
- `assignee`
- `components`
- `labels`

**When using AskUserQuestion, surface config defaults as the first (recommended) option:**

Example — if `config.yaml` provides `Assignee: <assignee_name>` and `Components: <component_name>`:
```json
{
  "questions": [
    {
      "question": "What type of issue is this?",
      "header": "Issue Type",
      "options": [
        {"label": "Task", "description": "A concrete piece of work"},
        {"label": "Story", "description": "A user-facing feature"},
        {"label": "Bug", "description": "Something broken"},
        {"label": "Epic", "description": "A large body of work"}
      ],
      "multiSelect": false
    }
  ]
}
```

If `project_key` is missing from config, add a project question. If `assignee` is missing, add an assignee question. Only include questions for truly missing fields — don't ask for what you already know.

**Resolve assignee to account ID:**

Jira Cloud requires the account ID format (e.g., `XXXXXX:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`) for assignee. If the user provides a name or email instead of an account ID, use `mcp__mcp-atlassian__confluence_search_user` to resolve it:

1. Check if the assignee value matches the account ID format (contains `:` and looks like `XXXXXX:uuid`)
2. If NOT in account ID format, search using Confluence:
   ```text
   mcp__mcp-atlassian__confluence_search_user
   {
     "query": "user.fullname ~ \"<assignee_name>\""
   }
   ```
   Or for email:
   ```text
   mcp__mcp-atlassian__confluence_search_user
   {
     "query": "user.fullname ~ \"<assignee_username>\""
   }
   ```
3. Extract the `account_id` from the search result
4. Use the resolved account ID for the `assignee` parameter

**Example resolution flow:**
- User provides: `<assignee_username>` or `<assignee_name>` or `<assignee_email>`
- Search via Confluence → Returns `account_id: <account_id>`
- Use this account ID when creating the issue

### Step 5: Create the Issue

Creating the issue uses a **two-step process** to ensure the description renders correctly in Jira. Passing description directly to `jira_create_issue` causes newlines to be mishandled — `* bullet` items get converted to `_ italic _` markers. Setting the description via `jira_update_issue` after creation avoids this entirely.

**Step 5a — Create the issue skeleton (no description yet):**

```text
mcp__mcp-atlassian__jira_create_issue
{
  "project_key": "<project_key>",
  "summary": "Self-Hosted LLM Serving Infrastructure",
  "issue_type": "Epic",
  "assignee": "<account_id>",
  "components": "<component_name>",
  "additional_fields": {
    "labels": ["infrastructure", "poc"],
    "parent": "<issue_key>"   ← include if subtask/child
  }
}
```

Note the absence of `description` here — intentional.

**Step 5b — Set the description via update (immediately after Step 5a):**

Extract the `issue_key` from the creation response, then call:

```text
mcp__mcp-atlassian__jira_update_issue
{
  "issue_key": "<issue_key>",
  "fields": {
    "description": "h3. Why\n\n* reason one\n* reason two\n\nh3. What\n\n..."
  }
}
```

Passing description through the `fields` dict preserves newlines correctly, so Jira wiki markup (`h3.`, `*`, `[ ]`) renders as intended.

### Step 6: Verify and Report Results

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
  "issue_key": "<issue_key>",
  "fields": "assignee,components,status"
}
```

**Report to user:**
Present the following information:
1. **Issue Key** (e.g., <issue_key>)
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
- Issue Key: <issue_key>
- URL: https://yourorg.atlassian.net/browse/<issue_key>
- Status: TO DO
- Issue Type: Epic
- Components: <component_name> ✓
- Assignee: [Status]

[Any additional notes or warnings]
```

## Best Practices

1. **Always collect metadata early**: Ask for project_key, issue_type, and other metadata during Step 1 to avoid back-and-forth

2. **Extract implicit information**: Users often provide metadata in their request (e.g., "create an Epic in <project_key>" → issue_type=Epic, project_key=<project_key>)

3. **Use the description template**: Structured descriptions improve communication and tracking

4. **Adapt to issue type**: Not all sections are needed for every issue type (Tasks may be simpler than Epics)

5. **Always get user approval**: Never create an issue without user review of the content

6. **Provide clear feedback**: After creation, give the user all the information they need to find and work with the issue

7. **Handle errors gracefully**: If creation fails or fields can't be set (like assignee), inform the user clearly and provide guidance

8. **Use English for all content**: See Step 2 for details

## MCP Tools Reference

This skill uses the following MCP Atlassian tools:

### For project discovery:
- `mcp__mcp-atlassian__jira_get_all_projects` - List available projects

### For creation:
- `mcp__mcp-atlassian__jira_create_issue` - Create the issue

### For verification (optional):
- `mcp__mcp-atlassian__jira_get_issue` - Verify issue details

### For user resolution:
- `mcp__mcp-atlassian__confluence_search_user` - Search for user account ID by name or email

### For metadata discovery:
- `mcp__mcp-atlassian__jira_search_fields` - Find custom field IDs
- `mcp__mcp-atlassian__jira_get_project_versions` - List fix versions

## Resources

### references/description-template.md
Detailed template and guidelines for creating well-structured issue descriptions. Includes examples and best practices for different issue types.

### references/metadata-guide.md
Comprehensive guide to Jira metadata fields including required vs. optional fields, formats, examples, and collection strategies.
