# Plan: Continuous Learning

## Origin

- Kickoff: `changes/2026-04-15_continuous-learning/1-kickoff.md`
- Autopsy: `changes/2026-04-15_continuous-learning/problem-autopsy.md`

## Approach

Build a shared continuous-learning system at the kaleidoscope-tools root level. It persists agent-level judgment errors (not code defects, not coding preferences) as project-scoped knowledge in `<project>/.learnings/`. A three-layer loading strategy (index → active set → archive) keeps context cost bounded regardless of learning count.

This replaces the ECC-derived `skills/continuous-learning-v2/` with a ground-up design aligned to yin-side philosophy: learn what breaks, not what works.

## Architecture

```
                  Human corrects Agent
                         |
                         v
              ┌─────────────────────┐
              │   Learning Writer   │ (agent writes immediately)
              │   .learnings/       │
              │   YYYY-MM-DD_slug.md│
              └────────┬────────────┘
                       │
                       v
              ┌─────────────────────┐
              │   Index Manager     │ (rebuild index.yaml)
              │   30 active entries │
              │   overflow → archive│
              └────────┬────────────┘
                       │
            ┌──────────┴──────────┐
            v                     v
   ┌────────────────┐   ┌────────────────┐
   │ Session Loader  │   │  Query Skill   │
   │ (hook, passive) │   │  (on demand)   │
   │ loads index     │   │  loads full    │
   │ one-liners      │   │  learning text │
   └────────────────┘   └────────────────┘
```

## Components

### 1. Learning File Format (.learnings/*.md)

```yaml
---
id: 2026-04-15_jest-vitest
domain: testing
trigger: "When configuring or running tests in this project"
created: 2026-04-15
last_validated: 2026-04-15
status: active  # active | archived
source_session: <session-id or "manual">
---

# Jest/Vitest Confusion

## What went wrong
Agent assumed this project uses Jest and configured test commands accordingly.

## Root cause
Project uses Vitest (configured in vite.config.ts). Package.json has no Jest dependency.

## Correct approach
Use `npx vitest` for test execution. Test config is in `vite.config.ts`, not `jest.config.js`.

## Context
This project migrated from Jest to Vitest in 2026-03. Some test files still have Jest-style imports that Vitest supports via compatibility mode.
```

**Format rationale:**
- YAML frontmatter for machine-readable indexing (domain, trigger, status, dates)
- Markdown body for human-readable detail (structured but not rigidly typed)
- Four sections: what went wrong / root cause / correct approach / context
- No workflow-specific vocabulary (no "death case", no "scar") — neutral language

### 2. Index File (.learnings/index.yaml)

```yaml
version: 1
last_rebuilt: 2026-04-15T10:30:00Z
active_count: 3
archived_count: 0

entries:
  - id: 2026-04-15_jest-vitest
    domain: testing
    one_liner: "This project uses Vitest not Jest — use npx vitest, config in vite.config.ts"
    created: 2026-04-15

  - id: 2026-04-15_migration-no-lock
    domain: database
    one_liner: "DB migrations cannot use table locks — production has read replicas"
    created: 2026-04-15
```

**Bounded at 30 active entries.** When count exceeds 30, oldest entries by `last_validated` are set to `status: archived` in their .md files and removed from index.yaml active entries.

### 3. SessionStart Hook (check-learnings)

A bash script registered in samsara's hooks.json. Pattern follows existing `check-codebase-map` hook:

1. Check if `${CLAUDE_PROJECT_DIR}/.learnings/index.yaml` exists
2. If missing → exit 0 (no injection, zero cost)
3. If present → read `entries[].one_liner`, format as a compact list
4. Inject via `hookSpecificOutput.additionalContext`

**Injection format:**

```
Project Learnings (N active):
- [testing] This project uses Vitest not Jest
- [database] DB migrations cannot use table locks
Use samsara:recall to query full details.
```

Estimated cost: ~30 entries × ~15 tokens = ~450 tokens (< 0.25% of context).

### 4. Recall Skill (samsara:recall)

A utility skill for on-demand querying of full learning content:

```
/samsara:recall               # list all active learnings
/samsara:recall testing       # filter by domain
/samsara:recall migration     # keyword search in one_liners
```

Reads matching .md files from `.learnings/` and presents full content.

### 5. Index Rebuild Script

A bash script that scans `.learnings/*.md`, parses YAML frontmatter, and regenerates `index.yaml`. Handles:
- New files without index entries (orphan detection — Death Case 1)
- Index entries pointing to deleted files (stale reference — Death Case 2)
- Archive threshold enforcement (> 30 active → oldest archived)
- Integrity check output: reports orphans, stale refs, and archived count

Called by:
- Learning Writer (after each write)
- Manually when `.learnings/` is modified by hand or git

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Shared at kaleidoscope-tools level, not samsara-exclusive | Knowledge belongs to the project, not the tool. Any workflow can write/read. |
| In-repo `.learnings/` directory | Follows git, portable across machines, shareable in teams. |
| YAML frontmatter + markdown body | Machine-indexable + human-readable. Consistent with samsara's existing formats. |
| Bounded 30 active entries | Keeps context cost < 0.25%. Three-layer (index/active/archive) scales indefinitely. |
| No confidence scoring in Phase 1 | ECC's confidence model is yang-side (frequency → belief). Yin-side model TBD. |
| No background observer agent | Immediate write-on-correction is simpler and sufficient. Observer adds infra complexity. |
| SessionStart hook pattern | Follows `check-codebase-map` precedent. Zero cost when no learnings exist. |
| Replace ECC continuous-learning-v2, not modify it | Completely different learning target (judgment errors vs preferences). Ground-up design. |

## Scope Boundaries (Explicitly Not Doing)

- No coding preference learning (auto memory handles this)
- No system-level failure tracking (scar reports handle this)
- No changes to existing samsara skill flows
- No multi-platform adapters beyond Claude Code (Phase 5)
- No cross-project learning promotion (Phase 5)
- No background observer or automated analysis agent
- No confidence scoring or decay formulas

## Deferred to Implementation

- Exact regex/parsing for YAML frontmatter extraction in bash (keep simple, use grep/sed or python)
- Whether `.learnings/` should be in `.gitignore` by default or committed (team decision — leaning toward committed for team sharing)
- How the existing `skills/continuous-learning-v2/` ECC copy should be handled (delete? archive?)
