# Setup Flow

Runs once, when [SKILL.md](../SKILL.md) Step 0 finds no config at either the project or global path. Produces a config file and validates it before any ticket operation proceeds.

## 1. Ask scope

Use AskUserQuestion:

- **Question**: "This ticket-tracking setup — apply it to every project, or just this one?"
- **Options**:
  - "All projects (global)" — stored once, reused everywhere. Recommended default.
  - "Just this project" — overrides the global config (if any) only inside this repo.

Record the answer as `scope`: `"global"` or `"project"`. This decides which of the two paths in SKILL.md Step 0 gets written.

## 2. Ask which platforms to enable

Use AskUserQuestion with `multiSelect: true`:

- **Question**: "Which ticket-tracking platform(s) should this skill use?"
- **Options**: "Jira", "Linear" (both selectable — a user can genuinely run both, e.g. company Jira + personal Linear).

If neither MCP server's tools are visible in this session for a platform the user picks, tell them before proceeding — enabling a platform here doesn't install its MCP server.

## 3. Per selected platform, ask label and defaults

For each platform selected in step 2, ask (one AskUserQuestion per platform, or combine if the harness supports multiple questions in one call):

- **Label**: a short word distinguishing this platform when more than one is enabled (e.g. "company", "personal"). Free text — offer "company" / "personal" / "default" as example options plus a custom answer.
- **Defaults**: platform-specific, ask only what that provider needs to create things without re-asking every time:
  - Jira: `project_key`, `assignee` (name/email — resolved to account ID at use time via [providers/jira.md](../providers/jira.md)), `components`, `labels`
  - Linear: `team_key`, `assignee`, `labels`

Store raw values as given (name/email, not resolved IDs) — resolution to platform-internal IDs happens per-operation in the provider files, not at setup time, because IDs can go stale.

Do not ask for or store API tokens, keys, or credentials here. Those belong to the MCP server's own configuration, never to this file — see the secret-key check in `scripts/validate_config.py`.

## 4. Ask default_platform (only if 2+ platforms enabled)

If exactly one platform was enabled, skip this — set `default_platform` to that platform automatically.

If multiple platforms are enabled, ask which one should be the pre-selected option when a future request doesn't specify a platform (SKILL.md still asks in that case — this only sets which option is pre-highlighted, it does not silently decide).

## 5. Assemble and write

```json
{
  "scope": "global",
  "platforms": {
    "jira": {
      "enabled": true,
      "label": "company",
      "defaults": { "project_key": "ABC", "assignee": null, "components": [], "labels": [] }
    },
    "linear": {
      "enabled": true,
      "label": "personal",
      "defaults": { "team_key": "ENG", "assignee": null, "labels": [] }
    }
  },
  "default_platform": "jira"
}
```

Write to the path matching the scope answer from step 1:

- `scope: "global"` → `${CLAUDE_PLUGIN_DATA}/ticket-tracking/config.json`
- `scope: "project"` → `${CLAUDE_PROJECT_DIR}/.claude/plugin-data/kaleidoscope-tools/ticket-tracking/config.json`

Create parent directories as needed.

## 6. Validate — required, not optional

Run:
```
uv run python ${CLAUDE_PLUGIN_ROOT}/skills/productivity/ticket-tracking/scripts/validate_config.py <path-written-in-step-5>
```

- Exit 0 (`VALID: ...`): proceed to the requested operation.
- Exit 1 (`INVALID: ...`): read the listed problems, fix the JSON, rewrite the file, and re-run the validator. Do not proceed to any ticket-tracking operation on an unvalidated config.
