---
name: handoff
description: "Use when quota is low and Claude needs to hand off work to another coding agent (Codex, Gemini CLI), or when the user manually requests a handoff. Generates a structured YAML document capturing task state, workflow progress, and pointers to relevant files."
---

# Quota Guard — Handoff

Generate a structured YAML handoff document so another coding agent can continue this work.

## When This Runs

- **Automatic**: Stop hook detected low quota and blocked. You MUST execute this skill immediately.
- **Manual**: User invoked `/quota-guard:handoff` to proactively hand off before quota runs out.

## Process

1. **Read the template** at `${CLAUDE_PLUGIN_ROOT}/skills/handoff/template.yaml`
2. **Read quota data** from `~/.claude/runtime/quota/{session_id}.json` (if it exists)
3. **Fill every field** based on your conversation context:
   - `handoff.trigger`: `"quota_low"` if auto-triggered, `"manual"` if user-invoked
   - `handoff.source_agent`: `"claude-code"`
   - `quota.*`: from the quota state file
   - `project.*`: current working directory, git branch
   - `workflow.*`: which skill/workflow you're using, what phase you're in
   - `tasks.*`: what's done, what's in progress, what remains — use YOUR understanding of the work, not just the task list
   - `context.*`: key decisions, blockers, assumptions the next agent should know
   - `files.*`: paths to code map, recently modified files, relevant docs
   - `notes`: anything else the next agent needs to know
4. **Write the handoff** to `docs/handoff/{YYYY-MM-DD}-{HHmmss}-handoff.yaml`
   - Create the `docs/handoff/` directory if it doesn't exist
   - The filename timestamp is critical — it serves as the guard marker
5. **Include session_id in the YAML** — the Stop hook uses this to detect the guard marker
6. **Tell the user** handoff is complete:
   - Show the handoff file path
   - Show when quota resets (from `quota.earliest_reset_at`)
   - Suggest closing the session and opening Codex/Gemini CLI in the same project directory
   - Mention: "The next agent should read `docs/handoff/` to pick up where we left off."

## Critical Rules

- **All file paths in the YAML must be relative** to the project root — not absolute paths
- **Do NOT include git state** (status, diff) — the next agent checks that itself
- **Do NOT copy file contents** — only include paths as pointers
- **Be specific in tasks** — "implement the Stop hook guard logic" is better than "continue working"
- **Fill EVERY field** — leave nothing as empty string unless truly not applicable (use `null` for N/A)
