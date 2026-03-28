---
name: deliberate-consensus
description: Run a structured deliberation workflow with stance generation, cross-examination, belief revision, arbitration, and dossier generation. Use when a decision needs adversarial testing rather than a single opinion.
---

# Deliberative Consensus Workflow

## Core Principle

> Consensus is not aggregation; consensus is adversarially tested survival.

Do NOT skip any stage. Do NOT produce a ruling without cross-examination. The value of this workflow is in the structured conflict, not the final answer.

## State Machine

```
START → Stage 0 (Framing)
      → Stage 1 (Stance Generation) [parallel x3]
        → if < 2 agents succeeded → ABORT
      → Stage 2 (Cross-Examination) [parallel x3]
      → Stage 3 (Belief Revision) [parallel x3]
      → Stage 4 (Arbitration) [single]
      → Stage 5 (Dossier)
      → END
```

You MUST follow this sequence. No skipping stages. No jumping to conclusions.

## Agents

| Agent | File | Role |
|-------|------|------|
| analytical-critic | `.claude/agents/analytical-critic.md` | Logical/technical analysis |
| risk-critic | `.claude/agents/risk-critic.md` | Risk/failure analysis |
| pragmatic-critic | `.claude/agents/pragmatic-critic.md` | Practical/delivery analysis |
| arbiter | `.claude/agents/arbiter.md` | Final ruling |

## Templates

Schema references for each stage are in `.claude/skills/deliberate-consensus/templates/`.

---

## Stage 0 — Task Framing

**Actor:** You (Coordinator / main session)

**Steps:**
1. Generate a `decision_id` in format `YYYYMMDD-HHMMSS-<short-slug>` (e.g., `20260329-143022-review-auth-middleware`)
2. Create the output directory:
   ```
   mkdir -p .claude/outputs/decisions/{decision_id}
   ```
3. Analyze the user's request and relevant codebase to formulate the problem
4. Write `stage0-framing.md` to `.claude/outputs/decisions/{decision_id}/stage0-framing.md`
   - Follow the schema in `templates/stage0-framing.md`
   - Include: problem statement, evaluation axes, evidence scope, context
5. Announce to the user: "Stage 0 complete. Framing written to {path}. Proceeding to stance generation."

---

## Stage 1 — Stance Generation

**Actor:** 3 critic agents in parallel

**Steps:**
1. Spawn ALL THREE agents simultaneously using parallel Agent tool calls:

   For each agent, use this prompt structure:
   ```
   You are executing Stage 1 (Stance Generation) of a deliberative consensus workflow.

   DECISION ID: {decision_id}

   Read the framing document at:
   .claude/outputs/decisions/{decision_id}/stage0-framing.md

   Investigate the codebase as needed using Read, Glob, and Grep.

   Write your stance to:
   .claude/outputs/decisions/{decision_id}/stage1-{agent-name}.md

   Follow the output schema in:
   .claude/skills/deliberate-consensus/templates/stage1-stance.md

   IMPORTANT:
   - Form your stance INDEPENDENTLY — do not look for other critics' outputs
   - Every critical claim must cite evidence (file:line or command output)
   - Mark unsupported claims as [HYPOTHESIS]
   ```

2. Wait for all agents to complete
3. Verify results:
   - Check that at least 2 out of 3 agents produced valid output files
   - If < 2 succeeded → ABORT: notify user and explain which agents failed
   - If 2 succeeded → proceed but note in dossier that only 2 perspectives were available
   - If 3 succeeded → proceed normally
4. Announce: "Stage 1 complete. {N}/3 stances generated. Proceeding to cross-examination."

---

## Stage 2 — Cross-Examination

**Actor:** 3 critic agents in parallel

**Steps:**
1. Spawn ALL THREE agents simultaneously using parallel Agent tool calls:

   For each agent, use this prompt structure:
   ```
   You are executing Stage 2 (Cross-Examination) of a deliberative consensus workflow.

   DECISION ID: {decision_id}

   Your identity: {agent-name}

   Read the following Stage 1 stance files from the OTHER two critics:
   - .claude/outputs/decisions/{decision_id}/stage1-{other-agent-1}.md
   - .claude/outputs/decisions/{decision_id}/stage1-{other-agent-2}.md

   You may also reference your own Stage 1 stance at:
   .claude/outputs/decisions/{decision_id}/stage1-{agent-name}.md

   Write your cross-examination to:
   .claude/outputs/decisions/{decision_id}/stage2-{agent-name}-cross-exam.md

   Follow the output schema in:
   .claude/skills/deliberate-consensus/templates/stage2-cross-exam.md

   IMPORTANT:
   - You MUST attack each of the other two critics on at least one point
   - Attacks must be specific — "I disagree" is not an attack
   - Reference concrete evidence where possible
   ```

2. Wait for all agents to complete
3. Announce: "Stage 2 complete. Cross-examinations generated. Proceeding to belief revision."

---

## Stage 3 — Belief Revision

**Actor:** 3 critic agents in parallel

**Steps:**
1. Spawn ALL THREE agents simultaneously using parallel Agent tool calls:

   For each agent, use this prompt structure:
   ```
   You are executing Stage 3 (Belief Revision) of a deliberative consensus workflow.

   DECISION ID: {decision_id}

   Your identity: {agent-name}

   Read the cross-examination attacks directed at YOU from the other two critics:
   - .claude/outputs/decisions/{decision_id}/stage2-{other-agent-1}-cross-exam.md
   - .claude/outputs/decisions/{decision_id}/stage2-{other-agent-2}-cross-exam.md

   Also re-read your original Stage 1 stance:
   .claude/outputs/decisions/{decision_id}/stage1-{agent-name}.md

   Write your belief revision to:
   .claude/outputs/decisions/{decision_id}/stage3-{agent-name}-revision.md

   Follow the output schema in:
   .claude/skills/deliberate-consensus/templates/stage3-revision.md

   IMPORTANT:
   - Be intellectually honest — if an attack is valid, acknowledge it
   - Changing your position is a sign of rigor, not weakness
   - You must explicitly state whether your position changed and why
   - Do not introduce entirely new arguments — respond to the attacks
   ```

2. Wait for all agents to complete
3. Announce: "Stage 3 complete. Belief revisions generated. Proceeding to arbitration."

---

## Stage 4 — Arbitration

**Actor:** Arbiter agent (single spawn)

**Steps:**
1. Spawn the arbiter agent with this prompt:

   ```
   You are executing Stage 4 (Arbitration) of a deliberative consensus workflow.

   DECISION ID: {decision_id}

   Read ALL of the following artifacts in order:

   Framing:
   .claude/outputs/decisions/{decision_id}/stage0-framing.md

   Stage 1 — Initial Stances:
   .claude/outputs/decisions/{decision_id}/stage1-analytical-critic.md
   .claude/outputs/decisions/{decision_id}/stage1-risk-critic.md
   .claude/outputs/decisions/{decision_id}/stage1-pragmatic-critic.md

   Stage 2 — Cross-Examinations:
   .claude/outputs/decisions/{decision_id}/stage2-analytical-critic-cross-exam.md
   .claude/outputs/decisions/{decision_id}/stage2-risk-critic-cross-exam.md
   .claude/outputs/decisions/{decision_id}/stage2-pragmatic-critic-cross-exam.md

   Stage 3 — Belief Revisions:
   .claude/outputs/decisions/{decision_id}/stage3-analytical-critic-revision.md
   .claude/outputs/decisions/{decision_id}/stage3-risk-critic-revision.md
   .claude/outputs/decisions/{decision_id}/stage3-pragmatic-critic-revision.md

   Write your arbitration ruling to:
   .claude/outputs/decisions/{decision_id}/stage4-arbiter.md

   Follow the output schema in:
   .claude/skills/deliberate-consensus/templates/stage4-arbitration.md

   IMPORTANT:
   - Do NOT introduce new arguments not raised by the critics
   - Do NOT re-analyze the codebase — judge only what was argued
   - Evidence-poor claims receive reduced weight
   - Always produce a minority report
   - Always list unresolved questions
   ```

2. Wait for arbiter to complete
3. Announce: "Stage 4 complete. Arbitration ruling generated. Assembling dossier."

---

## Stage 5 — Decision Dossier

**Actor:** You (Coordinator / main session)

**Steps:**
1. Read `stage4-arbiter.md` to get the ruling, minority report, and unresolved questions
2. Read all `stage1-*.md` files to get initial confidence values and recommendations
3. Read all `stage3-*.md` files to get revised confidence values and position changes
4. Write `dossier.md` to `.claude/outputs/decisions/{decision_id}/dossier.md`
   - Follow the schema in `templates/dossier.md`
   - Include: artifact index, belief changes summary, final ruling reference, minority report, unresolved questions, next actions
   - Do NOT rewrite any agent's content — reference and index only
5. Present the dossier summary to the user:
   - Ruling and consensus type
   - Key belief changes
   - Minority report highlights
   - Unresolved questions
   - Suggested next actions
6. Announce: "Deliberation complete. Full dossier at {path}."

---

## Content Ownership Rules

| File | Owner | Rule |
|------|-------|------|
| stage0-framing.md | Coordinator | Only you write this |
| stage1-{agent}.md | That critic | Only that agent writes this |
| stage2-{agent}-cross-exam.md | That critic | Only that agent writes this |
| stage3-{agent}-revision.md | That critic | Only that agent writes this |
| stage4-arbiter.md | Arbiter | Only the arbiter writes this |
| dossier.md | Coordinator | Only you write this; index/reference only |

**Immutability:** Once any artifact is written, it must NOT be modified. Each file is a permanent record.

## Evidence Policy

- Every critical claim must cite at least one evidence reference (`file:line` or command output)
- Claims without evidence must be marked as `[HYPOTHESIS]`
- Cross-exam attacks must target specific assumptions, evidence gaps, or reasoning flaws
- The Arbiter gives reduced weight to evidence-poor claims
- If critical evidence is missing, the ruling may degrade to `investigate`

## Stop Conditions

- **Normal end:** 1 full cycle (Stage 1→2→3) + Arbiter ruling → dossier
- **Abort:** Stage 1 produces < 2 valid stances → notify user
- **Fallback:** Arbiter determines critical evidence is missing → ruling = `investigate`
- **Max rounds:** MVP is fixed at 1 round (no looping back to Stage 2)
