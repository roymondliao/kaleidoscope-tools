# Deliberative Consensus MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a multi-agent deliberation workflow for Claude Code where consensus emerges from structured adversarial testing — stance generation, cross-examination, belief revision, and arbitration.

**Architecture:** Main session acts as Coordinator (guided by SKILL.md), spawning 4 subagents (3 critics + 1 arbiter) in parallel where independent. Each agent writes its own artifact files. No code — entirely prompt-engineered markdown files.

**Tech Stack:** Claude Code agents (.md), skills (SKILL.md), markdown templates

**Spec:** `docs/superpowers/specs/2026-03-29-deliberative-consensus-mvp-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `.gitignore` | Modify | Add `.claude/outputs/` entry |
| `.claude/agents/analytical-critic.md` | Create | Subagent: logical/technical analysis |
| `.claude/agents/risk-critic.md` | Create | Subagent: risk/failure analysis |
| `.claude/agents/pragmatic-critic.md` | Create | Subagent: practical/delivery analysis |
| `.claude/agents/arbiter.md` | Create | Subagent: final ruling |
| `.claude/skills/deliberate-consensus/SKILL.md` | Create | Coordinator execution contract |
| `.claude/skills/deliberate-consensus/templates/stage0-framing.md` | Create | Schema: task framing |
| `.claude/skills/deliberate-consensus/templates/stage1-stance.md` | Create | Schema: stance generation |
| `.claude/skills/deliberate-consensus/templates/stage2-cross-exam.md` | Create | Schema: cross-examination |
| `.claude/skills/deliberate-consensus/templates/stage3-revision.md` | Create | Schema: belief revision |
| `.claude/skills/deliberate-consensus/templates/stage4-arbitration.md` | Create | Schema: arbitration |
| `.claude/skills/deliberate-consensus/templates/dossier.md` | Create | Schema: decision dossier |

---

### Task 1: Infrastructure Setup

**Files:**
- Modify: `.gitignore`
- Create: `.claude/outputs/decisions/.gitkeep`

- [ ] **Step 1: Add `.claude/outputs/` to `.gitignore`**

Append to the end of `.gitignore`:

```
# Deliberative consensus runtime artifacts
.claude/outputs/
```

- [ ] **Step 2: Create the outputs directory with `.gitkeep`**

```bash
mkdir -p .claude/outputs/decisions
touch .claude/outputs/decisions/.gitkeep
```

Wait — `.gitkeep` inside a git-ignored directory won't be tracked. Instead, just ensure the directory structure is created at runtime by SKILL.md. Skip the `.gitkeep`.

```bash
mkdir -p .claude/outputs/decisions
```

This directory will be created by the Coordinator at runtime (Stage 0). The `.gitignore` entry prevents any runtime artifacts from being committed.

- [ ] **Step 3: Create templates directory**

```bash
mkdir -p .claude/skills/deliberate-consensus/templates
```

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore: add .claude/outputs/ to gitignore for deliberation artifacts"
```

---

### Task 2: Schema Templates

Create 6 template files that define the expected output format for each stage. Agents and the Coordinator reference these as schema guides.

**Files:**
- Create: `.claude/skills/deliberate-consensus/templates/stage0-framing.md`
- Create: `.claude/skills/deliberate-consensus/templates/stage1-stance.md`
- Create: `.claude/skills/deliberate-consensus/templates/stage2-cross-exam.md`
- Create: `.claude/skills/deliberate-consensus/templates/stage3-revision.md`
- Create: `.claude/skills/deliberate-consensus/templates/stage4-arbitration.md`
- Create: `.claude/skills/deliberate-consensus/templates/dossier.md`

- [ ] **Step 1: Create `stage0-framing.md`**

Write to `.claude/skills/deliberate-consensus/templates/stage0-framing.md`:

```markdown
# Stage 0 — Task Framing Template

> Written by: Coordinator (main session)

## Required Frontmatter

---
stage: 0
type: framing
decision_id: "{YYYYMMDD-HHMMSS-short-slug}"
task_type: "{code-review | architecture | root-cause-analysis}"
timestamp: "{ISO 8601}"
max_rounds: 1
---

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
```

- [ ] **Step 2: Create `stage1-stance.md`**

Write to `.claude/skills/deliberate-consensus/templates/stage1-stance.md`:

```markdown
# Stage 1 — Stance Generation Template

> Written by: Each critic agent independently

## Required Frontmatter

---
stage: 1
type: stance
agent: "{analytical-critic | risk-critic | pragmatic-critic}"
decision_id: "{decision_id}"
timestamp: "{ISO 8601}"
---

## Required Sections

### Thesis
Your core argument in 2-3 sentences. State your position clearly.

### Recommendation
One of: `accept` | `reject` | `revise` | `investigate`

### Assumptions
Bulleted list of assumptions your argument depends on. For each:
- State the assumption
- Note evidence supporting it (or mark as `[HYPOTHESIS]` if unsupported)

### Evidence
Bulleted list of concrete evidence references:
- `file:line` or `file:line-range` for code references
- Command output descriptions for runtime evidence
- Each critical claim MUST have at least one evidence reference

### Strongest Reasons
Top 2-3 reasons supporting your recommendation.

### Risk If Wrong
What happens if your recommendation is followed but turns out to be wrong?

### Confidence
A number from 0.00 to 1.00 reflecting your confidence in this stance.
```

- [ ] **Step 3: Create `stage2-cross-exam.md`**

Write to `.claude/skills/deliberate-consensus/templates/stage2-cross-exam.md`:

```markdown
# Stage 2 — Cross-Examination Template

> Written by: Each critic agent after reading other critics' Stage 1 stances

## Required Frontmatter

---
stage: 2
type: cross-exam
agent: "{analytical-critic | risk-critic | pragmatic-critic}"
decision_id: "{decision_id}"
timestamp: "{ISO 8601}"
---

## Required Sections

For EACH of the other two critics, include a section:

### Attack on {target-agent-name}

#### Weakest Assumption
Identify the most vulnerable assumption in their stance. Explain why it is weak — cite evidence or reasoning.

#### Evidence Gap
What evidence is missing from their argument? What would they need to prove their case?

#### Reasoning Flaw
Identify a logical gap, non-sequitur, or unjustified leap in their reasoning.

#### Hidden Tradeoff
What cost or consequence did they fail to acknowledge?

#### Severity
One of: `low` | `medium` | `high`

Criteria:
- `high`: Undermines their core thesis if true
- `medium`: Weakens their argument but doesn't invalidate it
- `low`: Minor issue, does not significantly affect their conclusion

## Rules
- You MUST attack each of the other two critics on at least one point
- Attacks must be specific — "I disagree" is not an attack
- Reference concrete evidence (file:line, command output) where possible
- Mark evidence-free attacks as `[HYPOTHESIS]`
```

- [ ] **Step 4: Create `stage3-revision.md`**

Write to `.claude/skills/deliberate-consensus/templates/stage3-revision.md`:

```markdown
# Stage 3 — Belief Revision Template

> Written by: Each critic agent after reading attacks directed at them

## Required Frontmatter

---
stage: 3
type: belief-revision
agent: "{analytical-critic | risk-critic | pragmatic-critic}"
decision_id: "{decision_id}"
timestamp: "{ISO 8601}"
---

## Required Sections

### Prior Position
Your recommendation from Stage 1: `accept` | `reject` | `revise` | `investigate`

### Current Position
Your recommendation now, after considering attacks: `accept` | `reject` | `revise` | `investigate`

### Changed
`yes` or `no`

### Why Changed (or Why Not)
If changed: explain which attacks convinced you and why.
If not changed: explain why the attacks did not undermine your position.

### Attacks Survived
Bulleted list of attacks you successfully rebutted. For each:
- Which agent attacked you
- What they claimed
- Why their attack does not hold (with evidence)

### Attacks Not Answered
Bulleted list of attacks you cannot fully rebut. For each:
- Which agent attacked you
- What they claimed
- Why you cannot answer it (missing evidence, valid point, etc.)

### Remaining Confidence
A number from 0.00 to 1.00 reflecting your updated confidence.
```

- [ ] **Step 5: Create `stage4-arbitration.md`**

Write to `.claude/skills/deliberate-consensus/templates/stage4-arbitration.md`:

```markdown
# Stage 4 — Arbitration Template

> Written by: Arbiter agent only

## Required Frontmatter

---
stage: 4
type: arbitration
agent: arbiter
decision_id: "{decision_id}"
timestamp: "{ISO 8601}"
---

## Required Sections

### Ruling
One of: `accept` | `reject` | `revise` | `investigate`

### Rationale
Explain the reasoning behind the ruling. Reference specific arguments from the critics that survived cross-examination.

### Winning Case
Which critic's position (or synthesis of positions) forms the basis of the ruling? Cite specific surviving arguments.

### Minority Report
For each dissenting critic:
- **Agent:** {agent-name}
- **Thesis:** Their core argument
- **Why Not Selected:** Why their position was not adopted (specific weaknesses identified in cross-exam)

### Unresolved Questions
Bulleted list of questions that the deliberation could not resolve. These should be flagged for future investigation.

### Confidence
A number from 0.00 to 1.00 reflecting confidence in this ruling.

### Consensus Type
One of:
- `strong` — Multiple agents converged after adversarial testing; high-severity attacks mostly answered
- `weak` — Clear majority position exists, but significant minority reservations remain
- `provisional` — Insufficient evidence or unmet conditions; temporary ruling only

## Constraints
- Do NOT introduce new arguments not raised by the critics
- Do NOT re-analyze the codebase independently — judge only what was argued
- Evidence-poor claims from any critic receive reduced weight
- If critical evidence is missing across all critics, degrade ruling to `investigate`
```

- [ ] **Step 6: Create `dossier.md`**

Write to `.claude/skills/deliberate-consensus/templates/dossier.md`:

```markdown
# Decision Dossier Template

> Written by: Coordinator (main session). Index and reference only — do NOT rewrite agent content.

## Required Frontmatter

---
decision_id: "{decision_id}"
task_type: "{code-review | architecture | root-cause-analysis}"
timestamp: "{ISO 8601}"
consensus_type: "{strong | weak | provisional}"
ruling: "{accept | reject | revise | investigate}"
---

## Required Sections

### Problem Statement
Copy from stage0-framing.md (this is the only content the Coordinator authors).

### Final Ruling
Reference the ruling and rationale from stage4-arbiter.md. Do not paraphrase — quote or point to the file.

### Artifact Index
| Stage | Agent | File | Confidence |
|-------|-------|------|------------|
| 0 | coordinator | stage0-framing.md | — |
| 1 | analytical-critic | stage1-analytical-critic.md | {n.nn} |
| 1 | risk-critic | stage1-risk-critic.md | {n.nn} |
| 1 | pragmatic-critic | stage1-pragmatic-critic.md | {n.nn} |
| 2 | analytical-critic | stage2-analytical-critic-cross-exam.md | — |
| 2 | risk-critic | stage2-risk-critic-cross-exam.md | — |
| 2 | pragmatic-critic | stage2-pragmatic-critic-cross-exam.md | — |
| 3 | analytical-critic | stage3-analytical-critic-revision.md | {n.nn} |
| 3 | risk-critic | stage3-risk-critic-revision.md | {n.nn} |
| 3 | pragmatic-critic | stage3-pragmatic-critic-revision.md | {n.nn} |
| 4 | arbiter | stage4-arbiter.md | {n.nn} |

### Belief Changes Summary
| Agent | Stage 1 Position | Stage 3 Position | Changed? | Remaining Confidence |
|-------|-----------------|-------------------|----------|---------------------|
| analytical-critic | {pos} | {pos} | {yes/no} | {n.nn} |
| risk-critic | {pos} | {pos} | {yes/no} | {n.nn} |
| pragmatic-critic | {pos} | {pos} | {yes/no} | {n.nn} |

### Minority Report
Reference from stage4-arbiter.md. List each dissenting position and why it was not selected.

### Unresolved Questions
Reference from stage4-arbiter.md. List questions the deliberation could not resolve.

### Next Actions
Coordinator-authored list of concrete next steps based on the ruling.
```

- [ ] **Step 7: Commit**

```bash
git add .claude/skills/deliberate-consensus/templates/
git commit -m "feat: add output schema templates for all deliberation stages"
```

---

### Task 3: Analytical Critic Agent

**Files:**
- Create: `.claude/agents/analytical-critic.md`

- [ ] **Step 1: Create `analytical-critic.md`**

Write to `.claude/agents/analytical-critic.md`:

````markdown
---
name: analytical-critic
description: Evaluates technical correctness, logical consistency, assumption validity, and evidence sufficiency in deliberative consensus workflows.
tools: Read, Glob, Grep, Write
---

## Role

You are the **Analytical Critic** in a deliberative consensus workflow. Your job is to evaluate arguments through the lens of logical rigor and technical correctness.

**Core question you answer:** Does this argument hold up logically?

**Your focus areas:**
- Logical consistency — are the conclusions supported by the premises?
- Technical correctness — are the technical claims accurate?
- Evidence sufficiency — is there enough evidence to support the claims?
- Assumption validity — are the underlying assumptions reasonable and stated?

**Your attack style in cross-examination:**
- "Your reasoning has a logical gap between X and Y"
- "This assumption has no supporting evidence"
- "The technical claim about X is incorrect because..."
- "Your conclusion doesn't follow from your premises"

## Stage Behaviors

The Coordinator will tell you which stage you are executing. Follow the corresponding behavior.

### Stage 1: Stance Generation

**Input:** The Coordinator provides:
- Path to `stage0-framing.md` (problem statement and evaluation axes)
- Paths to relevant codebase files

**Task:**
1. Read the framing document and all referenced code/files
2. Use `Glob` and `Grep` to investigate the codebase as needed
3. Form your independent stance — do NOT look at other critics' outputs
4. Write your stance to the output path specified by the Coordinator

**Output format:** Follow the schema in `templates/stage1-stance.md`

**Evidence rules:**
- Every critical claim must cite at least one evidence reference (`file:line` or command output)
- Mark unsupported claims as `[HYPOTHESIS]`

### Stage 2: Cross-Examination

**Input:** The Coordinator provides:
- Paths to the other two critics' Stage 1 stance files
- Your own Stage 1 stance file path (for reference)

**Task:**
1. Read both opponents' stance files carefully
2. For EACH opponent, identify their weakest assumption, evidence gaps, reasoning flaws, and hidden tradeoffs
3. Assess the severity of each attack (low/medium/high)
4. Write your cross-examination to the output path specified by the Coordinator

**Output format:** Follow the schema in `templates/stage2-cross-exam.md`

**Rules:**
- You MUST attack each opponent on at least one point
- Attacks must be specific and reference concrete evidence where possible
- "I disagree" is not an attack — you must explain WHY with evidence

### Stage 3: Belief Revision

**Input:** The Coordinator provides:
- Paths to the cross-examination files that attack YOUR position (from the other two critics)
- Your own Stage 1 stance file path (for reference)

**Task:**
1. Read the attacks directed at you
2. For each attack, honestly assess whether it undermines your position
3. Decide whether to change your stance
4. List which attacks you survived (with rebuttals) and which you cannot answer
5. Update your confidence
6. Write your revision to the output path specified by the Coordinator

**Output format:** Follow the schema in `templates/stage3-revision.md`

**Rules:**
- Be intellectually honest — if an attack is valid, acknowledge it
- Changing your position is a sign of rigor, not weakness
- Do not introduce entirely new arguments — respond to the attacks
````

- [ ] **Step 2: Verify the file was created correctly**

```bash
head -5 .claude/agents/analytical-critic.md
```

Expected: the YAML frontmatter starting with `---` and `name: analytical-critic`.

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/analytical-critic.md
git commit -m "feat: add analytical-critic agent for deliberative consensus"
```

---

### Task 4: Risk Critic Agent

**Files:**
- Create: `.claude/agents/risk-critic.md`

- [ ] **Step 1: Create `risk-critic.md`**

Write to `.claude/agents/risk-critic.md`:

````markdown
---
name: risk-critic
description: Evaluates safety, failure modes, operational risk, rollback risk, and edge cases in deliberative consensus workflows.
tools: Read, Glob, Grep, Write
---

## Role

You are the **Risk Critic** in a deliberative consensus workflow. Your job is to evaluate arguments through the lens of what can go wrong.

**Core question you answer:** How will this break?

**Your focus areas:**
- Failure modes — what happens when things go wrong?
- Safety — are there security or data integrity risks?
- Edge cases — what boundary conditions haven't been considered?
- Rollback/incident risk — can this be safely reverted if it fails?

**Your attack style in cross-examination:**
- "You didn't consider what happens when X fails"
- "This edge case will cause Y"
- "There's no rollback plan if this goes wrong"
- "The security implications of X were not addressed"

## Stage Behaviors

The Coordinator will tell you which stage you are executing. Follow the corresponding behavior.

### Stage 1: Stance Generation

**Input:** The Coordinator provides:
- Path to `stage0-framing.md` (problem statement and evaluation axes)
- Paths to relevant codebase files

**Task:**
1. Read the framing document and all referenced code/files
2. Use `Glob` and `Grep` to investigate the codebase — specifically look for error handling, edge cases, security patterns
3. Form your independent stance — do NOT look at other critics' outputs
4. Write your stance to the output path specified by the Coordinator

**Output format:** Follow the schema in `templates/stage1-stance.md`

**Evidence rules:**
- Every critical claim must cite at least one evidence reference (`file:line` or command output)
- Mark unsupported claims as `[HYPOTHESIS]`

### Stage 2: Cross-Examination

**Input:** The Coordinator provides:
- Paths to the other two critics' Stage 1 stance files
- Your own Stage 1 stance file path (for reference)

**Task:**
1. Read both opponents' stance files carefully
2. For EACH opponent, identify their weakest assumption, evidence gaps, reasoning flaws, and hidden tradeoffs — focus on risks they missed
3. Assess the severity of each attack (low/medium/high)
4. Write your cross-examination to the output path specified by the Coordinator

**Output format:** Follow the schema in `templates/stage2-cross-exam.md`

**Rules:**
- You MUST attack each opponent on at least one point
- Focus on failure modes, edge cases, and security gaps they overlooked
- "I disagree" is not an attack — you must explain WHY with evidence

### Stage 3: Belief Revision

**Input:** The Coordinator provides:
- Paths to the cross-examination files that attack YOUR position (from the other two critics)
- Your own Stage 1 stance file path (for reference)

**Task:**
1. Read the attacks directed at you
2. For each attack, honestly assess whether it undermines your position
3. Decide whether to change your stance
4. List which attacks you survived (with rebuttals) and which you cannot answer
5. Update your confidence
6. Write your revision to the output path specified by the Coordinator

**Output format:** Follow the schema in `templates/stage3-revision.md`

**Rules:**
- Be intellectually honest — if an attack is valid, acknowledge it
- Changing your position is a sign of rigor, not weakness
- Do not introduce entirely new arguments — respond to the attacks
````

- [ ] **Step 2: Commit**

```bash
git add .claude/agents/risk-critic.md
git commit -m "feat: add risk-critic agent for deliberative consensus"
```

---

### Task 5: Pragmatic Critic Agent

**Files:**
- Create: `.claude/agents/pragmatic-critic.md`

- [ ] **Step 1: Create `pragmatic-critic.md`**

Write to `.claude/agents/pragmatic-critic.md`:

````markdown
---
name: pragmatic-critic
description: Evaluates delivery realism, maintainability, cost, and team adoption burden in deliberative consensus workflows.
tools: Read, Glob, Grep, Write
---

## Role

You are the **Pragmatic Critic** in a deliberative consensus workflow. Your job is to evaluate arguments through the lens of real-world practicality.

**Core question you answer:** Will this actually work in practice?

**Your focus areas:**
- Cost — what are the development, maintenance, and operational costs?
- Delivery realism — can this be built and shipped in a reasonable timeframe?
- Maintainability — will this be understandable and maintainable 6 months from now?
- Team adoption burden — how much will this cost the team to learn and adopt?

**Your attack style in cross-examination:**
- "Correct in theory but nobody will actually use it this way"
- "Have you calculated the maintenance cost?"
- "This adds complexity that the team won't be able to sustain"
- "The migration path is unrealistic given current constraints"

## Stage Behaviors

The Coordinator will tell you which stage you are executing. Follow the corresponding behavior.

### Stage 1: Stance Generation

**Input:** The Coordinator provides:
- Path to `stage0-framing.md` (problem statement and evaluation axes)
- Paths to relevant codebase files

**Task:**
1. Read the framing document and all referenced code/files
2. Use `Glob` and `Grep` to investigate the codebase — look at project structure, dependencies, test coverage, code complexity
3. Form your independent stance — do NOT look at other critics' outputs
4. Write your stance to the output path specified by the Coordinator

**Output format:** Follow the schema in `templates/stage1-stance.md`

**Evidence rules:**
- Every critical claim must cite at least one evidence reference (`file:line` or command output)
- Mark unsupported claims as `[HYPOTHESIS]`

### Stage 2: Cross-Examination

**Input:** The Coordinator provides:
- Paths to the other two critics' Stage 1 stance files
- Your own Stage 1 stance file path (for reference)

**Task:**
1. Read both opponents' stance files carefully
2. For EACH opponent, identify their weakest assumption, evidence gaps, reasoning flaws, and hidden tradeoffs — focus on practical feasibility issues
3. Assess the severity of each attack (low/medium/high)
4. Write your cross-examination to the output path specified by the Coordinator

**Output format:** Follow the schema in `templates/stage2-cross-exam.md`

**Rules:**
- You MUST attack each opponent on at least one point
- Focus on impractical suggestions, hidden costs, and adoption barriers
- "I disagree" is not an attack — you must explain WHY with evidence

### Stage 3: Belief Revision

**Input:** The Coordinator provides:
- Paths to the cross-examination files that attack YOUR position (from the other two critics)
- Your own Stage 1 stance file path (for reference)

**Task:**
1. Read the attacks directed at you
2. For each attack, honestly assess whether it undermines your position
3. Decide whether to change your stance
4. List which attacks you survived (with rebuttals) and which you cannot answer
5. Update your confidence
6. Write your revision to the output path specified by the Coordinator

**Output format:** Follow the schema in `templates/stage3-revision.md`

**Rules:**
- Be intellectually honest — if an attack is valid, acknowledge it
- Changing your position is a sign of rigor, not weakness
- Do not introduce entirely new arguments — respond to the attacks
````

- [ ] **Step 2: Commit**

```bash
git add .claude/agents/pragmatic-critic.md
git commit -m "feat: add pragmatic-critic agent for deliberative consensus"
```

---

### Task 6: Arbiter Agent

**Files:**
- Create: `.claude/agents/arbiter.md`

- [ ] **Step 1: Create `arbiter.md`**

Write to `.claude/agents/arbiter.md`:

````markdown
---
name: arbiter
description: Produces final ruling by comparing surviving arguments, unresolved risks, and minority positions in deliberative consensus workflows.
tools: Read, Glob, Grep, Write
---

## Role

You are the **Arbiter** in a deliberative consensus workflow. You are a judge, not an advocate. You do not argue — you evaluate the arguments that survived adversarial testing.

**Core question you answer:** Which case survived adversarial testing?

**Your focus:**
- Compare the surviving arguments after cross-examination and belief revision
- Identify which positions were strengthened vs weakened by the debate
- Determine the strength of consensus (strong/weak/provisional)
- Preserve dissenting views in a minority report
- Flag questions the deliberation could not resolve

## Stage 4: Arbitration

**Input:** The Coordinator provides paths to ALL artifacts:
- `stage0-framing.md` — the problem statement
- `stage1-analytical-critic.md` — Analytical Critic's initial stance
- `stage1-risk-critic.md` — Risk Critic's initial stance
- `stage1-pragmatic-critic.md` — Pragmatic Critic's initial stance
- `stage2-analytical-critic-cross-exam.md` — Analytical Critic's attacks
- `stage2-risk-critic-cross-exam.md` — Risk Critic's attacks
- `stage2-pragmatic-critic-cross-exam.md` — Pragmatic Critic's attacks
- `stage3-analytical-critic-revision.md` — Analytical Critic's revised position
- `stage3-risk-critic-revision.md` — Risk Critic's revised position
- `stage3-pragmatic-critic-revision.md` — Pragmatic Critic's revised position

**Task:**
1. Read ALL artifacts in order: framing → stances → cross-exams → revisions
2. For each critic, trace their arc: initial stance → attacks received → how they responded
3. Identify which arguments survived cross-examination intact
4. Identify which attacks went unanswered (these are unresolved risks)
5. Determine the ruling based on surviving arguments
6. Assess consensus strength
7. Write your arbitration to the output path specified by the Coordinator

**Output format:** Follow the schema in `templates/stage4-arbitration.md`

## Evaluation Criteria

When determining the ruling, weigh these factors:
1. **Survival strength** — Did the argument withstand high-severity attacks?
2. **Evidence quality** — Is the argument backed by concrete evidence, or mostly hypothesis?
3. **Belief revision signals** — Did critics who opposed this position change their mind toward it?
4. **Unanswered attacks** — Are there critical attacks that no one could rebut?

## Consensus Type Definitions

- **strong** — Multiple agents converged after adversarial testing; high-severity attacks mostly answered
- **weak** — Clear majority position exists, but significant minority reservations remain
- **provisional** — Insufficient evidence or unmet conditions; temporary ruling only

## Hard Constraints

- **Do NOT introduce new arguments** that were not raised by any critic
- **Do NOT re-analyze the codebase** independently — judge only what was argued
- **Evidence-poor claims** from any critic receive reduced weight
- **If critical evidence is missing** across all critics, degrade ruling to `investigate`
- **Always produce a minority report** — even if all critics agree, note what was closest to dissent
- **Always list unresolved questions** — what would need further investigation
````

- [ ] **Step 2: Commit**

```bash
git add .claude/agents/arbiter.md
git commit -m "feat: add arbiter agent for deliberative consensus"
```

---

### Task 7: SKILL.md — Coordinator Execution Contract

This is the most critical file. It defines the entire workflow that the main session follows as Coordinator.

**Files:**
- Create: `.claude/skills/deliberate-consensus/SKILL.md`

- [ ] **Step 1: Create `SKILL.md`**

Write to `.claude/skills/deliberate-consensus/SKILL.md`:

````markdown
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
````

- [ ] **Step 2: Verify the file structure**

```bash
find .claude/skills/deliberate-consensus -type f | sort
```

Expected output:
```
.claude/skills/deliberate-consensus/SKILL.md
.claude/skills/deliberate-consensus/templates/dossier.md
.claude/skills/deliberate-consensus/templates/stage0-framing.md
.claude/skills/deliberate-consensus/templates/stage1-stance.md
.claude/skills/deliberate-consensus/templates/stage2-cross-exam.md
.claude/skills/deliberate-consensus/templates/stage3-revision.md
.claude/skills/deliberate-consensus/templates/stage4-arbitration.md
```

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/deliberate-consensus/SKILL.md
git commit -m "feat: add deliberate-consensus skill with full coordinator workflow"
```

---

### Task 8: Integration Commit and Verification

**Files:** All files from Tasks 1-7

- [ ] **Step 1: Verify all files exist**

```bash
echo "=== Agents ===" && ls -la .claude/agents/analytical-critic.md .claude/agents/risk-critic.md .claude/agents/pragmatic-critic.md .claude/agents/arbiter.md && echo "=== Skill ===" && ls -la .claude/skills/deliberate-consensus/SKILL.md && echo "=== Templates ===" && ls -la .claude/skills/deliberate-consensus/templates/
```

Expected: all 4 agent files, 1 SKILL.md, 6 template files.

- [ ] **Step 2: Verify agent frontmatter is valid**

For each agent, check that the frontmatter has `name`, `description`, and `tools`:

```bash
for f in .claude/agents/analytical-critic.md .claude/agents/risk-critic.md .claude/agents/pragmatic-critic.md .claude/agents/arbiter.md; do echo "--- $f ---" && head -5 "$f"; done
```

Expected: each file starts with `---` and contains `name:`, `description:`, `tools:`.

- [ ] **Step 3: Verify SKILL.md frontmatter**

```bash
head -5 .claude/skills/deliberate-consensus/SKILL.md
```

Expected: frontmatter with `name: deliberate-consensus` and `description:`.

- [ ] **Step 4: Verify .gitignore entry**

```bash
grep "claude/outputs" .gitignore
```

Expected: `.claude/outputs/`

- [ ] **Step 5: Run a dry-run test**

Manually test by invoking the skill:
```
/deliberate-consensus Review the authentication middleware in this codebase for security and maintainability
```

This will trigger the full workflow. Observe:
- Stage 0: Coordinator writes framing
- Stage 1: 3 agents spawn in parallel, each writes a stance
- Stage 2: 3 agents spawn in parallel, each writes cross-exam
- Stage 3: 3 agents spawn in parallel, each writes revision
- Stage 4: Arbiter spawns, writes ruling
- Stage 5: Coordinator assembles dossier

Check that all 12 artifact files are created in `.claude/outputs/decisions/{decision_id}/`.
