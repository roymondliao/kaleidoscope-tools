# Overview: Continuous Learning

## Goal

Persist agent-level judgment errors as project-scoped knowledge in `<project>/.learnings/`, with bounded session loading via a three-layer strategy (index → active set → archive).

## Architecture

Shared infrastructure at kaleidoscope-tools root level. Four components: Learning Writer (agent writes .md), Index Manager (rebuilds index.yaml), Session Loader (SessionStart hook injects one-liners), and Recall Skill (on-demand full-text query). Storage is in-repo (`.learnings/` directory in target project), following git for portability.

## Tech Stack

- Bash: SessionStart hook (`check-learnings`), index rebuild script
- YAML: frontmatter in learning files, index.yaml
- Markdown: learning file body (human-readable)
- Skill YAML frontmatter: `samsara:recall` skill definition

## Key Decisions

- **Shared, not samsara-exclusive**: knowledge belongs to the project, any workflow can read/write
- **In-repo `.learnings/`**: portable across machines and platforms, team-shareable via git
- **Bounded 30 active entries**: keeps session loading cost < 0.25% of context
- **No confidence scoring (Phase 1)**: yin-side confidence model TBD, don't use yang-side frequency model
- **Replace ECC continuous-learning-v2**: completely different learning target, ground-up design
- **Neutral format**: no workflow-specific vocabulary in learning files

## Death Cases Summary

1. **Learning written but index not updated** — orphaned knowledge invisible to future sessions. Detect via file count vs index entry count mismatch.
2. **Index references deleted learning** — stale pointer causes query failure. Detect via file existence validation on load.
3. **Wrong learning persists forever** — incorrect correction teaches wrong lessons indefinitely. Mitigate via 90-day auto-archive on unvalidated entries.

## File Map

Target project (where learnings are stored):
- `<project>/.learnings/index.yaml` — bounded active index
- `<project>/.learnings/YYYY-MM-DD_slug.md` — individual learning files

kaleidoscope-tools (where infrastructure lives):
- `samsara/hooks/check-learnings` — SessionStart hook script
- `samsara/hooks/hooks.json` — hook registration (add new entry)
- `samsara/skills/recall/SKILL.md` — query skill
- `scripts/learnings-rebuild.sh` — index rebuild script (shared, not samsara-specific)
