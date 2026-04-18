# Continuous Learning — Implementation Issues

Issues discovered during the first implementation cycle. These belong to the continuous-learning feature (kaleidoscope-tools shared infrastructure), not to samsara.

---

## ISSUE-002: Python-in-bash heredoc pattern

**Discovered:** 2026-04-17
**Severity:** Medium

Implementer subagent embedded ~300 lines of Python in bash heredocs because the plan specified "Tech Stack: Bash." The correct pattern is thin bash wrapper (~10 lines) + proper `.py` file.

**Rule:** Bash does routing, Python does logic. Hook entry points are bash (platform requirement), but logic lives in `.py` files.

---

## ISSUE-003: Component without caller (learnings-rebuild.sh)

**Discovered:** 2026-04-17
**Severity:** High

`learnings-rebuild.sh` was fully implemented with tests and scar reports but had no integration point — no mechanism for anyone to call it. Plan assumed a "Learning Writer" that was never built.

**Resolution:** Absorbed by the observer in the two-layer architecture. The observer writes learnings AND maintains the index. No standalone rebuild script needed.

**Rule:** Every component in a plan must have a named caller. "Manual" or "the agent just knows" is not a valid caller.

---

## ISSUE-004: Architecture revision — two-layer design

**Discovered:** 2026-04-17
**Status:** Pending re-implementation

### Corrected Architecture

```
hooks/
├── check-learnings.sh              ← bash thin wrapper (~10 lines)
├── observe-learnings.sh            ← bash thin wrapper (UserPromptSubmit hook)
├── scripts/
│   ├── check-learnings.py       ← session loader logic (Python)
│   └── observe-learnings.py     ← writes observations.jsonl (Python)
└── hooks.json                   ← hook registration

agents/
└── learnings-observer.md        ← Haiku background agent
                                    reads observations.jsonl
                                    writes .learnings/*.md + index.yaml

skills/
└── recall-learnings/
    └── SKILL.md                 ← query skill (renamed from recall)

tests/
├── hooks/
│   ├── test-check-learnings.sh
│   └── test-observe-learnings.sh
└── ...
```

### Key Design Decisions

1. **Two-layer** (ECC-inspired): hook captures observations passively, background Haiku observer analyzes and writes learnings
2. **No standalone rebuild script**: observer handles both writing and indexing
3. **Thin bash wrappers**: hooks ~10 lines bash, logic in .py
4. **Shared ownership**: all at kaleidoscope-tools root, not samsara
5. **Naming**: `recall-learnings` (descriptive) not `recall` (ambiguous)
6. **Tests centralized**: `tests/<component>/`, not co-located

### Files to Delete (from wrong implementation)

```
scripts/learnings-rebuild.sh
scripts/tests/test-learnings-rebuild.sh
hooks/tests/                           (moved to tests/hooks/)
samsara/hooks/check-learnings          (if not already deleted)
samsara/hooks/tests/                   (if not already deleted)
samsara/skills/recall/                 (if not already deleted)
```

---

## ISSUE-005: Layer 2 runtime is completely missing — observer has no execution mechanism

**Discovered:** 2026-04-17
**Severity:** Critical — Layer 2 of the two-layer architecture exists only as a prompt definition, not a working system
**Status:** Pending implementation

### What Happened

After correcting the architecture to follow ECC's two-layer pattern, the implementation created:
- Layer 1: `observe-learnings.py` writes observations to JSONL (working)
- Layer 2: `learnings-observer.md` defines the Haiku analysis agent (prompt only)

But the bridge between Layer 1 and Layer 2 — and Layer 2's entire runtime — was never built. The observer agent has no mechanism to start, no mechanism to be triggered, and no mechanism to loop.

### ECC vs Our Implementation — Component-by-Component

```
ECC (complete):                          Ours (incomplete):

observe.sh                               observe-learnings.py
  ├── writes observations.jsonl    ✓       ├── writes observations.jsonl    ✓
  ├── lazy-starts observer daemon  ✗       ├── (missing)
  ├── manages PID file             ✗       ├── (missing)
  └── sends SIGUSR1 (throttled)    ✗       └── (missing)

start-observer.sh                        (missing entirely)
  └── nohup launch + PID file

observer-loop.sh                         (missing entirely)
  ├── trap SIGUSR1
  ├── cooldown throttle
  ├── idle timeout (auto-exit)
  ├── session lease tracking
  └── invokes Haiku for analysis

observer.md                              learnings-observer.md
  └── Haiku agent prompt           ✓       └── Haiku agent prompt           ✓
```

### What's Missing (4 components)

#### 1. SIGUSR1 Bridge (in observe-learnings.py)

`observe-learnings.py` writes JSONL and exits. It does not signal anyone. In ECC, `observe.sh` sends SIGUSR1 to the observer process every N observations (default 20), with throttling to prevent signal storms.

**Needed:** After writing to JSONL, check if observer daemon is running (PID file), and if throttle counter allows, send SIGUSR1.

#### 2. Daemon Launcher (start-observer.sh)

ECC has `start-observer.sh` which launches the observer loop as a nohup background process, writes a PID file, and sets up the working directory. It handles:
- Stale PID file detection (process died but PID file remains)
- Preventing duplicate launches (check if already running)
- nohup + stderr redirect to log file

**Needed:** `hooks/scripts/start-observer.sh` — launches the observer loop as a daemon.

#### 3. Background Loop (observer-loop.sh)

ECC has `observer-loop.sh` which runs as a long-lived process:
- `trap SIGUSR1` to wake on signal
- Sleep between iterations (default 5 min) but interruptible by signal
- Cooldown throttle (min 60s between analysis runs, prevent rapid re-triggering)
- Idle timeout (exit if no observations for 30 min and no active sessions)
- Session lease tracking (don't exit while Claude sessions are active)
- When triggered: invoke Haiku to analyze observations

**Needed:** `hooks/scripts/observer-loop.sh` — the background process that bridges observations → analysis → learnings.

#### 4. Haiku Invocation Mechanism

ECC's observer loop calls Claude with the Haiku model to analyze observations. The exact mechanism depends on the platform — ECC uses Claude Code's SDK or CLI to spawn a background session.

**Needed:** The observer loop needs a way to invoke the `learnings-observer` agent (Haiku model) to analyze accumulated observations. Options:
- `claude --model haiku --agent learnings-observer` (if Claude Code supports background agent invocation)
- Direct Anthropic API call via Python
- `claude -p "analyze these observations..."` with piped context

This is the most platform-dependent component and needs design before implementation.

### Dependency Chain

```
observe-learnings.py (Layer 1, exists)
    │
    ├── needs: PID file check + SIGUSR1 send + throttle counter
    │
    └──→ start-observer.sh (new)
            │
            └──→ observer-loop.sh (new)
                    │
                    ├── trap SIGUSR1
                    ├── cooldown + idle timeout
                    │
                    └──→ learnings-observer.md (exists, prompt only)
                            │
                            └── needs: invocation mechanism (TBD)
```

### Design Decisions (Resolved 2026-04-17)

| # | Decision | Chosen | Rationale |
|---|---|---|---|
| 1 | Haiku invocation | **Claude Code CLI** (`claude --model haiku -p "..."`) | Reuses existing Claude Code login, no API key management. Platform-portable for Phase 5 via abstraction layer. |
| 2 | Daemon state location | **OS temp** (`/tmp/learnings-observer-<project-hash>.*`) | Runtime state doesn't belong in git. Multi-machine naturally isolated. Project hash derived from repo path. |
| 3 | First observer start | **Lazy-start from hook** | Auto-starts on first observation. No SessionStart overhead. PID file check prevents duplicate launches. |
| 4 | Pending review gate | **Observer writes with `status: pending_review`; human confirms to `active`** | Chosen beyond original options. Yin-side requirement: false positive cost too high for auto-active. |

### Pending Review Gate — REVERSED 2026-04-17

**Decision 4 reversed during implementation discussion.** The pending_review gate
was initially chosen to prevent false-positive poisoning. It was reversed after
considering that:

1. Industry trend is toward agent autonomy — designing for today's imperfect
   agents produces systems that become obsolete in 6 months
2. The gate itself creates dead-infrastructure risk (ISSUE-003 reincarnated):
   pending learnings pile up unreviewed → never promoted → system adds no value
3. Better to ship auto-active with yin-side monitoring than to ship a gate
   that humans stop using

**New decision 4 (supersedes the pending_review model):**

Observer writes `status: active` directly. Yin-side safety is relocated from
the entry gate to continuous auditing and corruption detection.

### Status field values (final)

- `active` — In effect, loaded at session start.
- `invalidated` — A later correction contradicted this learning. Retained for audit, not loaded.
- `archived` — No longer applicable (e.g., project migration). Retained, not loaded.
- `superseded_by: <new_id>` — Optional frontmatter field recording successor.

### Corruption Signatures (new requirement)

The system must detect when its own learnings are wrong, without relying on
human review as the primary gate:

| Signature | Detection | Trigger |
|---|---|---|
| **Contradiction rate** | Observer flags when new correction opposes an existing active learning | Warn in check-learnings hook if > 2 in last 30 days |
| **Correction recurrence** | Same topic corrected multiple times across sessions despite existing learning | Indicates learning is not being applied OR is wrong |
| **Active learning growth without contradiction** | Monotone growth is suspicious (observer may be approving its own duplicates) | Audit alert |

### Observer Prompt Change

The Haiku observer MUST receive the current active learnings' one_liners as
context. When detecting corrections, it must classify:

- `new` — unrelated to existing learnings → create new active
- `supersedes` — contradicts existing → invalidate old, create new active, record `superseded_by`
- `reinforces` — same as existing → skip (no duplicate)

### /review-learnings skill repurposed

No longer a gate. Now an auditor:
- List active learnings + their contradiction history
- Let human invalidate a learning they know is wrong
- Show corruption signature metrics

### Cross-Platform Note (Deferred to Phase 5)

SIGUSR1, PID files, and nohup are POSIX conventions. Windows support is deferred. Abstraction layer can be added later — the Python script boundary is the right place for it.

### Current State Summary

| Component | Status | Location |
|-----------|--------|----------|
| observe-learnings hook | **Partial** — writes JSONL, missing signal/lazy-start | `hooks/scripts/observe-learnings.py` |
| check-learnings hook | **Complete** — reads index, injects context | `hooks/scripts/check-learnings.py` |
| recall-learnings skill | **Complete** — query interface defined | `skills/recall-learnings/SKILL.md` |
| learnings-observer agent | **Prompt only** — no runtime | `agents/learnings-observer.md` |
| start-observer daemon | **Missing** | — |
| observer-loop background | **Missing** | — |
| SIGUSR1 bridge | **Missing** | — |
| Haiku invocation mechanism | **Missing + needs design** | — |
