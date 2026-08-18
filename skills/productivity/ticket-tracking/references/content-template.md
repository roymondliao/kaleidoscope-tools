# Content Templates

Section structure by canonical tier (see [type-mapping.md](type-mapping.md)). The Project/Epic tier is fixed across all domains. The Parent and Child tiers are domain-specific — pick the domain template that matches the work, or extend one when the built-in set doesn't fit (see "Adding a domain" below).

Write the description in whatever language the user is working in, except when the target Jira project's team convention is English-only (ask if unsure — don't silently switch languages).

## Project/Epic (fixed, all domains)

```markdown
### Why
- Motivation and value proposition
- Problem being solved

### What
Brief description of what will be built or changed (2-3 sentences).

### Scope
- Specific deliverables

**Success Criteria**:
- [ ] Measurable outcome 1
- [ ] Measurable outcome 2

### Out of Scope
- What is explicitly NOT included, to prevent scope creep
```

This stays the same regardless of domain — at Project/Epic altitude the content is "why does this body of work exist and what defines it as done," which doesn't vary by whether the work is engineering, research, or personal learning.

## Issue/Task/Story (Parent) — domain-specific

### Domain: `engineering-delivery`

```markdown
## Goal
One-paragraph statement of the deliverable.

## Repository context
- Task contract: `<path>`
- Relevant design/behavior docs: `<path>#<anchor>`

## Scope
- What this task covers

## Out of scope
- What it explicitly does not cover

## Task sequence
1. Ordered/dependency-annotated list of the sub-issues this will be split into

## Exit criteria
- Conditions that must all hold for every child issue to be considered complete
```

Use when the work is implementation against a repository: file/doc references matter, and "done" is defined by tests and repo state, not just a description.

### Domain: `learning-topic`

```markdown
### 目標
（學完之後能做到什麼）

### 完成條件
- 可觀察、可驗證的產出（不是「讀過了」）

### 材料
- paper / repo / 課程 / 文件連結

### 產出
（筆記、程式碼、實驗紀錄的存放位置）
```

Use when the work is self-directed learning: there's no repository to anchor to, and "done" is defined by an observable artifact (notes, code, a written explanation), not a merged PR.

## Issue/Sub-task (Child) — domain-specific

Child-tier templates are deliberately leaner than their Parent-tier counterpart in the same domain — a child is one bounded, single-session unit of work, not a multi-deliverable body of work.

### Domain: `engineering-delivery`

```markdown
## Goal
One-paragraph statement of this specific deliverable.

## Repository context
- Task contract: `<path>`
- Relevant design/behavior docs: `<path>#<anchor>`

## In scope
- What this task covers

## Acceptance criteria
- Testable conditions specific to this task
```

Narrower than the Parent template: no `Task sequence` (this issue doesn't have children) and no `Exit criteria` (that lives on the parent, evaluated across all children).

### Domain: `learning-topic`

```markdown
### Block 1｜<動作>
（第一個 session 要做的事：通常是讀與推導）

### Block 2｜<動作>
（第二個 session 要做的事：通常是實作與驗證）

### 完成條件
- 可觀察、可驗證的產出
```

Optional trailing sections, include only when relevant:
- `### 承接` — how this connects to the previous or next sub-issue
- `### 備註` — anything that doesn't fit elsewhere (e.g. borrowing a week, deviating from the usual two-block split)
- `### 依據` — what existing design/schema this reuses instead of reinventing

A sub-issue is scoped to one weekly budget (2 blocks) per the project's time-budget convention — don't let Block 1/Block 2 content balloon into something that actually needs its own child issue.

## Adding a domain

The two domains above (`engineering-delivery`, `learning-topic`) came from auditing real Linear usage, not from a fixed enum — they are examples, not the full set. When a request doesn't fit either:

1. Ask the user what "done" looks like for this kind of work and what materials/context it should link to.
2. Propose a section list by adapting the closer of the two existing domains rather than inventing structure from scratch.
3. Only add a permanent new domain section to this file if the user confirms they'll reuse it — a one-off doesn't need to become a template.
