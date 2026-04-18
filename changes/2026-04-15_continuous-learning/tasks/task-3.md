# Task 3: Recall Skill (samsara:recall)

## Context
Read: overview.md

The recall skill is a utility skill for on-demand querying of full learning content. It is the Layer 2 (active set) mechanism — when an agent or human wants more detail than the one-liner summaries injected at session start, they invoke this skill to load full learning text into context.

Despite being in the `samsara/skills/` directory, this skill's content is workflow-neutral — it reads `.learnings/` files without assuming any specific workflow philosophy.

Depends on task-1 (index rebuild script) because it reads the index.yaml format.

## Files
- Create: `samsara/skills/recall/SKILL.md`

## Death Test Requirements
- Test: Skill invoked with domain filter "testing" when no learnings have domain "testing" → must report "No learnings found for domain: testing", not return empty or error
- Test: Skill invoked when `.learnings/` directory does not exist → must report "No learnings directory found in this project", not crash
- Test: Skill invoked when index.yaml entry points to a deleted .md file → must report "Learning file missing: <id>", not crash or silently skip
- Test: Skill invoked with no arguments when 40 learnings exist (30 active + 10 archived) → must show only 30 active by default, with note about 10 archived

## Skill Interface

```
/samsara:recall                    # list all active learnings (one-liners from index)
/samsara:recall <domain>           # filter by domain, show full content
/samsara:recall <keyword>          # keyword search in one_liners, show full content
/samsara:recall --all              # include archived learnings in results
```

## SKILL.md Structure

```yaml
---
name: recall
description: "Query project failure learnings from .learnings/ directory. Use when you need full detail about a past agent correction, or when session-start summary references a relevant learning."
argument-hint: "[domain, keyword, or --all to include archived]"
---
```

Skill body instructs the agent to:
1. Read `.learnings/index.yaml` from project root
2. Filter entries by argument (domain match or keyword in one_liner)
3. Read matching `.md` files for full content
4. Present results grouped by domain
5. If no matches found, report clearly (not silently empty)

## Implementation Steps
- [ ] Step 1: Write death test scenarios as comments in SKILL.md
- [ ] Step 2: Verify skill description triggers correctly (manual test)
- [ ] Step 3: Write SKILL.md with full query logic instructions
- [ ] Step 4: Test with mock `.learnings/` directory
- [ ] Step 5: Write scar report
- [ ] Step 6: Report (do not commit)

## Expected Scar Report Items
- Potential shortcut: Keyword search is simple string matching on one_liners — may miss relevant learnings where the keyword is only in the body, not the one_liner
- Assumption to verify: Skill description is specific enough to trigger on "recall", "past learnings", "what did we learn" without false-triggering on unrelated queries
- Assumption to verify: Reading 5-10 full learning .md files at once does not exceed reasonable context cost (~1000-2000 tokens)

## Acceptance Criteria
- Covers: "Success - recall skill returns full detail"
