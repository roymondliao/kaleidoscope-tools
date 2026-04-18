# Kickoff: Continuous Learning

## Problem Statement

AI agent sessions are independent — failure knowledge does not persist across sessions. When a human corrects an agent's process, usage, or development judgment in a specific project, that correction is lost when the session ends. The next session repeats the same mistakes. This is a distinct problem from scar reports (which track system-level code risks); continuous learning captures agent-level judgment errors in project-specific context.

## Evidence

- Scar reports exist per-task in `changes/` directories but are never aggregated or queried by future sessions.
- Claude Code's auto memory captures user preferences (feedback type) but not structured project-scoped failure patterns.
- ECC's continuous-learning-v2 (Homunculus) learns coding preferences (yang-side: "what works well"), not failure patterns (yin-side: "where the agent's judgment model has blind spots").
- Each session starts with zero knowledge of past agent errors in the project.

## Risk of Inaction

The same agent mistakes repeat across sessions in the same project. Human time is wasted re-correcting identical errors. Team members cannot benefit from corrections given by other team members' sessions. The cost of this grows linearly with project complexity and team size.

## Scope

### Must-Have (with death conditions)

- **In-repo storage (`.learnings/`)** — Death condition: if learnings files exceed 50 and no pruning mechanism exists, degrading repo signal-to-noise ratio
- **Three-layer loading (index → active set → archive)** — Death condition: if index summary exceeds 2% of context window and repeat failure rate does not decrease
- **Structured format (YAML frontmatter + markdown)** — Death condition: if cross-platform adapters cannot parse the format
- **Immediate write-on-correction** — Death condition: if write latency exceeds session boundary (corrections lost before persistence)
- **Platform adapter for Claude Code (SessionStart hook)** — Death condition: if hook reliability drops below 95% of sessions

### Nice-to-Have

- Confidence scoring with decay (needs yin-side model, not yang-side frequency-based)
- Cross-project promotion (wait for Phase 5 multi-platform)
- Background observer agent for post-session analysis
- Evolution/compression of related learnings into general rules

### Explicitly Out of Scope

- Coding style/preference learning (auto memory already handles this)
- System-level failure tracking (scar reports handle this)
- Changing existing samsara skill flows (research, planning, implement, debugging, validate-and-ship)
- Changing scar report format or purpose
- Multi-platform adapters beyond Claude Code (deferred to Phase 5)

## North Star

```yaml
metric:
  name: "Repeat Failure Rate"
  definition: "Percentage of human corrections where the same failure type already exists in .learnings/"
  current: "unmeasured (no system exists)"
  target: "< 5% after 30 learnings accumulated"
  invalidation_condition: "Project undergoes fundamental tech stack change, making all prior learnings inapplicable"
  corruption_signature: "Agent over-matches corrections to existing learnings to avoid recording new ones. Detect via: learnings_created_per_month trending to zero while human corrections continue."

sub_metrics:
  - name: "learnings_count"
    current: 0
    target: "organic growth, no artificial target"
    proxy_confidence: medium
    decoupling_detection: "Count grows but repeat rate doesn't drop — learnings quality is poor"
  - name: "time_since_last_correction"
    current: "N/A"
    target: "increasing trend"
    proxy_confidence: high
    decoupling_detection: "Could mean human gave up correcting, not that agent improved"
```

## Stakeholders

- **Decision maker:** yuyu_liao (project owner)
- **Impacted teams:** Any team using kaleidoscope-tools workflows on a project
- **Damage recipients:** Skill authors — shared format means learnings cannot use workflow-specific vocabulary (e.g., samsara's "death case" terminology). Must use neutral language.
