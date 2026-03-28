# Decision Dossier Template

> Written by: Coordinator (main session). Index and reference only — do NOT rewrite agent content.

## Required Frontmatter

```yaml
---
decision_id: "{decision_id}"
task_type: "{code-review | architecture | root-cause-analysis}"
timestamp: "{ISO 8601}"
consensus_type: "{strong | weak | provisional}"
ruling: "{accept | reject | revise | investigate}"
---
```

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
