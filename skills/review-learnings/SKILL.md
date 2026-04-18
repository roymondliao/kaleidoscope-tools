---
name: review-learnings
description: "Audit active project learnings and invalidate ones known to be wrong. Use when session-start shows corruption warnings, when /recall-learnings results seem off, or for periodic sanity review."
argument-hint: "[--contradictions | --recent | --suspect | <learning-id>]"
---

# Review Learnings — Audit Active Learnings

The learnings-observer ships learnings with `status: active` directly (no human
gate). This skill is the **auditor** — it lets you review what's active,
inspect corruption signatures, and invalidate learnings you know to be wrong.

## Why audit (not gate)?

The system is designed to trust the agent. Human gate was rejected because:
- It creates a dead-infrastructure risk (pending pileup)
- It assumes agent capability won't improve (it will)
- It makes humans the bottleneck

Yin-side safety is relocated to **corruption signatures** (detected
automatically) and **this audit skill** (invoked when signatures fire or on
demand).

## Interface

```
/review-learnings                 # summary of active learnings by domain + signature report
/review-learnings --contradictions  # show learnings with superseded_by history (chains)
/review-learnings --recent          # learnings created/updated in last 7 days
/review-learnings --suspect         # learnings with low confidence signals
/review-learnings <id>              # show full content of one learning, offer action menu
```

## Execution

### Step 1 — Read index.yaml

Read `.learnings/index.yaml`. Check `active_count`, `archived_count`,
`invalidated_count` (if present), and the new corruption metrics if the index
has them (see `check-learnings.py` for which signatures are tracked).

### Step 2 — Present audit summary (default action)

```
Active Learnings Audit
======================
Active:      N
Archived:    M
Invalidated: K

Corruption signatures:
  Contradictions last 30d:    X  (>2 is concerning)
  Correction recurrence rate: Y%  (>30% suggests learnings not applied)
  Monotone growth days:       Z   (>14 without invalidation is suspicious)

By domain:
  [tooling]       N1 active, K1 invalidated
  [architecture]  N2 active, K2 invalidated
  [process]       ...

Recent (last 7d):
  - <id>: <one_liner>
  - <id>: <one_liner>

Suspect (needs attention):
  - <id>: <reason>      # e.g., "superseded 3 times in 14 days"
```

### Step 3 — Argument handling

| Argument | Behavior |
|---|---|
| `--contradictions` | List active learnings whose frontmatter has `superseded_by`, or which superseded another. Show the chain. |
| `--recent` | List learnings with `created` or `last_validated` in last 7 days. |
| `--suspect` | Apply heuristics: frequent supersession (> 3 supersedes of same trigger), stale (last_validated > 90 days), or conflict flags. |
| `<id>` | Show the full .md file content, then present action menu (see Step 4). |

### Step 4 — Action menu for specific learning

When a specific learning is selected, use platform's blocking question tool
(`AskUserQuestion` in Claude Code) to offer:

| Action | Effect |
|---|---|
| **Keep active** | No change. Update `last_validated` to today (signals "I've reviewed this"). |
| **Invalidate** | Change `status: active` → `status: invalidated`. Record reason in frontmatter. |
| **Archive** | Change `status: active` → `status: archived`. For learnings that are obsolete but not wrong. |
| **Edit** | Let human edit the file. Changes apply immediately. |

### Step 5 — Rebuild index

After any modification, invoke:
```bash
python3 hooks/scripts/invoke-observer.py --rebuild-only <project_dir>
```

(If invoke-observer.py does not yet support `--rebuild-only`, call its internal
`_rebuild_index` function directly via a small Python invocation, or trigger
the observer manually.)

## Error Handling (mandatory)

| Condition | Required output |
|---|---|
| `.learnings/` missing | `No learnings directory found in this project` |
| No active learnings | `No active learnings to review.` |
| `.md` file unreadable | `Cannot read learning file: <path>` (continue to next) |
| Frontmatter has no `status` field | `Warning: learning missing status field: <id>` |
| Argument references non-existent id | `Learning not found: <id>` |

## Corruption Signatures (reference)

These are computed by `check-learnings.py` and surfaced here for audit context.
See `issues.md` under "Corruption Signatures" for the current list.

- **Contradiction rate** — supersedes per month
- **Correction recurrence** — same topic corrected multiple times despite learning
- **Monotone growth** — active count growing without any invalidations (suspect)

When any signature trips, `check-learnings` injects a warning at session start
recommending `/review-learnings`.
