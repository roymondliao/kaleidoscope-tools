# Deliberative Consensus MVP — Design Spec

## 1. Overview

### Purpose

Build a structured deliberation workflow for Claude Code where consensus emerges from adversarial testing, not majority voting. The system uses multiple subagents with distinct critical perspectives to generate stances, cross-examine each other, revise beliefs, and produce an arbitrated ruling with full provenance.

### Core Principle

> Consensus is not aggregation; consensus is adversarially tested survival.

A claim becomes consensus only if it survives structured cross-examination from multiple adversarial perspectives.

### MVP Scope

- **In scope:** 4 subagents (3 critics + arbiter), 1 skill (deliberate-consensus), artifact-based workflow, parallel agent spawning, code review as first test scenario
- **Out of scope:** multi-round deliberation loops, hooks, MCP orchestration, auto PR comments, autonomous code modification, schema validation

### Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Coordinator role | Main session | Claude Code subagents cannot spawn subagents; main session acts as Coordinator guided by SKILL.md |
| Agent file format | Single file (.md) | Deliberation agents are simpler than existing SOUL.md agents; one file per agent is sufficient |
| Orchestration model | Parallel where independent | Stage 1/2/3 agents are independent within each stage; parallel spawning preserves independence and improves speed |
| Artifact format | YAML frontmatter + Markdown body | Machine-parseable metadata + natural language reasoning; consistent with Claude Code agent file conventions |
| Agent write tool | Write (not Edit) | Agents create new files, not modify existing ones; Write doesn't require prior Read |
| Max rounds (MVP) | Fixed at 1 | Validate single-round deliberation quality before adding multi-round complexity |

---

## 2. File Structure

```
.claude/
  agents/
    analytical-critic.md
    risk-critic.md
    pragmatic-critic.md
    arbiter.md
  skills/
    deliberate-consensus/
      SKILL.md
      templates/
        stage0-framing.md
        stage1-stance.md
        stage2-cross-exam.md
        stage3-revision.md
        stage4-arbitration.md
        dossier.md
  outputs/
    decisions/              # runtime artifacts, git-ignored via .claude/.gitignore
```

> **Note:** Add `.claude/outputs/` to `.gitignore` (or `.claude/.gitignore`) to prevent runtime artifacts from being committed. Template and agent definition files should remain tracked.

### Runtime Artifacts

```
.claude/outputs/decisions/{decision_id}/
  stage0-framing.md
  stage1-analytical-critic.md
  stage1-risk-critic.md
  stage1-pragmatic-critic.md
  stage2-analytical-critic-cross-exam.md
  stage2-risk-critic-cross-exam.md
  stage2-pragmatic-critic-cross-exam.md
  stage3-analytical-critic-revision.md
  stage3-risk-critic-revision.md
  stage3-pragmatic-critic-revision.md
  stage4-arbiter.md
  dossier.md
```

`decision_id` format: `YYYYMMDD-HHMMSS-<short-slug>` (e.g., `20260329-143022-review-auth-middleware`)

---

## 3. System Roles

### Coordinator (Main Session)

Guided by SKILL.md. Responsibilities:
- Receive task, produce framing (Stage 0)
- Spawn subagents at each stage with precise prompts (file paths, output paths, stage instructions)
- Verify agent completion (>= 2 stances required to proceed)
- Assemble dossier (Stage 5) — index only, no rewriting of agent content

### Analytical Critic

| Aspect | Detail |
|---|---|
| Core question | Does this argument hold up logically? |
| Focus | Logical consistency, technical correctness, evidence sufficiency, assumption validity |
| Attack style | "Your reasoning has a logical gap", "This assumption has no evidence" |

### Risk Critic

| Aspect | Detail |
|---|---|
| Core question | How will this break? |
| Focus | Failure modes, safety, edge cases, rollback/incident risk |
| Attack style | "You didn't consider X failing", "This edge case will explode" |

### Pragmatic Critic

| Aspect | Detail |
|---|---|
| Core question | Will this actually work in practice? |
| Focus | Cost, delivery realism, maintainability, team adoption burden |
| Attack style | "Correct in theory but nobody will use it", "Have you calculated the maintenance cost?" |

### Arbiter

| Aspect | Detail |
|---|---|
| Core question | Which case survived adversarial testing? |
| Focus | Comparing surviving arguments, unresolved risks, consensus strength |
| Constraints | Cannot introduce new arguments not raised by critics; must preserve minority report; must flag unresolved questions |

---

## 4. Agent Definitions

All 4 agents use the same tools: `Read, Glob, Grep, Write`

Each critic `.md` contains three sections:
1. **Frontmatter** — name, description, tools
2. **Role definition** — perspective, focus areas, evaluation criteria
3. **Stage behaviors** — what to do in Stage 1 (stance), Stage 2 (cross-exam), Stage 3 (revision), with output schema for each

Arbiter `.md` contains:
1. **Frontmatter** — name, description, tools
2. **Role definition** — judge, not advocate
3. **Stage 4 behavior** — evaluation criteria, output schema, constraints (no new arguments)

---

## 5. SKILL.md — Coordinator Execution Contract

### Trigger

Slash command: `/deliberate-consensus <task-description>`

### Content Structure

1. **Purpose & Core Principle**
2. **State Machine** (digraph from Spec v2, embedded as execution contract)
3. **Stage Protocols** (per-stage execution steps)
4. **Artifact Rules** (naming, paths, content ownership)
5. **Stop Conditions**
6. **Evidence Policy**

### Stage Protocols

**Stage 0 — Framing (Coordinator):**
- Generate `decision_id`
- Create output directory `.claude/outputs/decisions/{decision_id}/`
- Write `stage0-framing.md` with problem statement + evaluation axes

**Stage 1 — Stance Generation (Parallel spawn x3):**
- Spawn analytical-critic, risk-critic, pragmatic-critic simultaneously
- Each reads stage0-framing.md + relevant codebase files
- Each writes own `stage1-{agent}.md`
- Coordinator verifies >= 2 succeeded, then proceeds

**Stage 2 — Cross-Examination (Parallel spawn x3):**
- Spawn all 3 critics simultaneously
- Each reads the other two critics' Stage 1 artifacts
- Each writes own `stage2-{agent}-cross-exam.md`
- Must attack each opponent on at least one point

**Stage 3 — Belief Revision (Parallel spawn x3):**
- Spawn all 3 critics simultaneously
- Each reads cross-exam attacks directed at themselves (from other two critics' Stage 2 artifacts)
- Each writes own `stage3-{agent}-revision.md`
- Must explicitly state whether position changed and why

**Stage 4 — Arbitration (Single spawn):**
- Spawn arbiter
- Reads all artifacts: stage0 + stage1 x3 + stage2 x3 + stage3 x3
- Writes `stage4-arbiter.md` with ruling, minority report, unresolved questions

**Stage 5 — Dossier (Coordinator):**
- Assemble `dossier.md`: artifact index, final ruling reference, belief changes summary, minority report, unresolved questions, next actions
- No rewriting of any agent content — index and reference only

---

## 6. Output Schemas

### Stage 1 — Stance

```yaml
---
stage: 1
type: stance
agent: "{agent-name}"
decision_id: "{decision_id}"
timestamp: "{ISO 8601}"
---
```

Body sections: Thesis, Recommendation (`accept | reject | revise | investigate`), Assumptions, Evidence, Strongest Reasons, Risk If Wrong, Confidence (0.00-1.00)

### Stage 2 — Cross-Examination

```yaml
---
stage: 2
type: cross-exam
agent: "{agent-name}"
decision_id: "{decision_id}"
timestamp: "{ISO 8601}"
---
```

Body sections: per target agent — Weakest Assumption, Evidence Gap, Reasoning Flaw, Hidden Tradeoff, Severity (`low | medium | high`)

### Stage 3 — Belief Revision

```yaml
---
stage: 3
type: belief-revision
agent: "{agent-name}"
decision_id: "{decision_id}"
timestamp: "{ISO 8601}"
---
```

Body sections: Prior Position, Current Position, Changed (yes/no), Why Changed, Attacks Survived, Attacks Not Answered, Remaining Confidence (0.00-1.00)

### Stage 4 — Arbitration

```yaml
---
stage: 4
type: arbitration
agent: arbiter
decision_id: "{decision_id}"
timestamp: "{ISO 8601}"
---
```

Body sections: Ruling (`accept | reject | revise | investigate`), Rationale, Winning Case, Minority Report (per dissenting agent: thesis + why not selected), Unresolved Questions, Confidence (0.00-1.00), Consensus Type (`strong | weak | provisional`)

### Dossier

```yaml
---
decision_id: "{decision_id}"
task_type: "{task_type}"
timestamp: "{ISO 8601}"
consensus_type: "{strong | weak | provisional}"
ruling: "{accept | reject | revise | investigate}"
---
```

Body sections: Problem Statement, Final Ruling, Artifact Index (table), Belief Changes Summary (table), Minority Report, Unresolved Questions, Next Actions

---

## 7. Content Ownership

| File pattern | Owner | Rule |
|---|---|---|
| stage0-framing.md | Coordinator | Only Coordinator writes |
| stage1-{agent}.md | Corresponding critic | Only that critic writes |
| stage2-{agent}-cross-exam.md | Corresponding critic | Only that critic writes |
| stage3-{agent}-revision.md | Corresponding critic | Only that critic writes |
| stage4-arbiter.md | Arbiter | Only Arbiter writes |
| dossier.md | Coordinator | Only Coordinator writes, index/reference only |

**Immutability rule:** Once written, no file may be modified by anyone. Each artifact is a permanent record of that agent's reasoning at that stage.

---

## 8. Evidence Policy

| Rule | Description |
|---|---|
| Citation required | Every critical claim must include at least one evidence reference |
| Citation format | `file:line`, `file:line-range`, or command output description |
| Hypothesis marking | Claims without evidence must be marked as `[HYPOTHESIS]` |
| Attack specificity | Cross-exam attacks must target specific assumption, evidence gap, or reasoning flaw |
| Arbiter weighting | Evidence-poor claims receive reduced weight in arbitration |
| Degradation | If critical evidence is missing, ruling may degrade to `investigate` |

---

## 9. Stop Conditions

| Condition | Result |
|---|---|
| 1 full cycle completed + Arbiter ruling produced | Normal end → dossier |
| Stage 1: < 2 agents succeeded | Abort → report failure |
| Critical evidence missing (Arbiter judgment) | Fallback → ruling = `investigate` |
| `max_rounds` reached (MVP: fixed at 1) | End deliberation → Stage 4 |

### MVP Simplifications

| Full version | MVP |
|---|---|
| Evidence Gap Check can loop back to Stage 2 | Fixed 1 round, no looping |
| `max_rounds` configurable | Hardcoded = 1 |
| Early convergence detection | Not implemented |
| Agent failure retry | No retry; check >= 2 succeeded |
| Output schema validation | No validation; prompt-guided only |

---

## 10. Consensus Labels

| Label | Definition |
|---|---|
| **strong** | Multiple agents converged after adversarial testing; high-severity attacks mostly answered |
| **weak** | Clear majority position exists, but significant minority reservations remain |
| **provisional** | Insufficient evidence or unmet conditions; temporary ruling only |

---

## 11. Files to Create

| # | File | Purpose |
|---|---|---|
| 1 | `.claude/agents/analytical-critic.md` | Subagent: logical/technical analysis |
| 2 | `.claude/agents/risk-critic.md` | Subagent: risk/failure analysis |
| 3 | `.claude/agents/pragmatic-critic.md` | Subagent: practical/delivery analysis |
| 4 | `.claude/agents/arbiter.md` | Subagent: final ruling |
| 5 | `.claude/skills/deliberate-consensus/SKILL.md` | Coordinator execution contract |
| 6 | `.claude/skills/deliberate-consensus/templates/stage0-framing.md` | Schema reference |
| 7 | `.claude/skills/deliberate-consensus/templates/stage1-stance.md` | Schema reference |
| 8 | `.claude/skills/deliberate-consensus/templates/stage2-cross-exam.md` | Schema reference |
| 9 | `.claude/skills/deliberate-consensus/templates/stage3-revision.md` | Schema reference |
| 10 | `.claude/skills/deliberate-consensus/templates/stage4-arbitration.md` | Schema reference |
| 11 | `.claude/skills/deliberate-consensus/templates/dossier.md` | Schema reference |
