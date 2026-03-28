# Stage 0 — Task Framing Template

> Written by: Coordinator (main session)

## Required Frontmatter

```yaml
---
stage: 0
type: framing
decision_id: "{YYYYMMDD-HHMMSS-short-slug}"
task_type: "{code-review | architecture | root-cause-analysis}"
timestamp: "{ISO 8601}"
max_rounds: 1
---
```

## Required Sections

### Problem Statement
A clear description of the decision to be made. Include:
- What is being evaluated (e.g., specific code, architecture choice, incident)
- Why this needs a deliberation (what makes it non-trivial)
- Scope boundaries (what is and isn't in scope)

### Evaluation Axes
Numbered list of criteria the critics should evaluate against. Example:
1. Technical correctness
2. Security posture
3. Maintainability
4. Performance impact

### Evidence Scope
What sources of evidence are available:
- File paths relevant to the decision
- Commands that can be run to gather evidence
- External references if applicable

### Context
Any additional context the critics need to understand the problem.
