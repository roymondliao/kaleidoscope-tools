# Kaleidoscope Tools

A collection of Claude Code plugins, skills, and agents for building structured AI-assisted development workflows.

## Plugins

### [Samsara](samsara/)

**向死而驗 — Death-first development workflow.**

A complete development lifecycle framework with existential accountability for every line of code. Includes research, planning, implementation, debugging, validation, and codebase mapping skills.

See [samsara/README.md](samsara/README.md) for details.

### [Quota Guard](quota-guard/)

**Quota monitoring & cross-tool handoff.**

Monitors Claude Code Pro subscription rate limits (5-hour and 7-day windows) via statusLine sampling. When remaining quota drops below a configurable threshold (default 8%), auto-pauses the session and generates a structured YAML handoff document — so you can seamlessly continue development in Codex, Gemini CLI, or any other coding agent.

**Components:**

| Component | Purpose |
|-----------|---------|
| `quota-sampler.sh` | Samples `rate_limits` from statusLine stdin, writes to runtime file |
| `quota-wrapper.sh` | Composable statusLine wrapper — chains sampler with your existing statusLine |
| `quota-stop-guard.sh` | Stop hook — blocks when quota is low, guides Claude to generate handoff |
| `emergency-snapshot.sh` | StopFailure fallback — minimal handoff when rate limit is already hit |
| `/quota-guard:handoff` | Skill that Claude executes to produce the handoff YAML |

**Setup:**

1. Enable the plugin in `~/.claude/settings.json`:
   ```json
   { "enabledPlugins": { "quota-guard@kaleidoscope-tools": true } }
   ```
2. Point your statusLine to the wrapper:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "QUOTA_GUARD_USER_STATUSLINE=/path/to/your/statusline.sh bash /path/to/quota-guard/scripts/quota-wrapper.sh"
     }
   }
   ```
3. Set `QUOTA_GUARD_USER_STATUSLINE` to your existing statusLine script path (optional — if omitted, a default display is used).

**Configuration (environment variables):**

| Variable | Default | Description |
|----------|---------|-------------|
| `QUOTA_GUARD_THRESHOLD` | `8` | Remaining % to trigger handoff |
| `QUOTA_GUARD_USER_STATUSLINE` | _(none)_ | Path to your original statusLine script |

## Skills

Standalone skills that can be used across projects.

| Skill | Description |
|-------|-------------|
| `level-analysis` | Analyze problems from Senior/Staff/Principal engineering perspectives |
| `deliberate-consensus` | Structured deliberation with stance generation, cross-examination, and arbitration |
| `deep-reading-analyst` | Deep analysis of user-provided links with structured insights |
| `browser-qa` | Automated QA testing for web platforms using chrome-devtools-mcp |
| `create-jira-issue` | Systematic requirements gathering for Jira issue creation |
| `context-sentinel-check` | Verify agent context retention; auto-compact if lost |
| `zettelkasten-coach` | Transform literature into Zettelkasten permanent notes |
| `obsidian-organizer` | Organize Obsidian vaults in Research-Optimized Zettelkasten style |

## Agents

Specialized sub-agents for targeted tasks.

| Agent | Description |
|-------|-------------|
| `ai-research` | AI Research Educator & Systems Architect with Python/DevOps expertise |
| `analytical-critic` | Evaluates technical correctness and logical consistency |
| `arbiter` | Produces final ruling by comparing arguments and unresolved risks |
| `pragmatic-critic` | Evaluates delivery realism, maintainability, and adoption burden |
| `risk-critic` | Evaluates safety, failure modes, and operational risk |

## Installation

This project is registered as a Claude Code plugin marketplace. Add it to your `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "kaleidoscope-tools": {
      "source": {
        "source": "directory",
        "path": "/path/to/kaleidoscope-tools"
      }
    }
  }
}
```

Then enable individual plugins via `enabledPlugins`.

## Requirements

- Claude Code CLI
- `jq` (for shell-based hooks and scripts)
- `bc` (for quota calculations)

## License

Private project by Roymond Liao.
