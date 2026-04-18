---
name: recall-learnings
description: "Query project failure learnings from .learnings/ directory. Use when you need full detail about a past agent correction, or when session-start summary references a relevant learning."
argument-hint: "[domain, keyword, or --all to include archived]"
---

# Recall Learnings — Query Project Failure Knowledge

Load full content of project failure learnings on demand. When session-start one-liners are not enough detail, this skill fetches the full text.

This skill reads `.learnings/` in the current project root. It is workflow-neutral — it does not assume samsara or any other workflow.

## Interface

```
/recall-learnings                    # list all active learnings (one-liners from index)
/recall-learnings <domain>           # filter by domain, show full content
/recall-learnings <keyword>          # keyword search in one_liners, show full content
/recall-learnings --all              # include archived learnings in results
```

## Execution

### Step 1 — Check .learnings/ exists

Look for `.learnings/` directory at the project root (same directory as the top-level README or .git/).

**If `.learnings/` does not exist:**
Report exactly: `No learnings directory found in this project`
Stop. Do not continue.

### Step 2 — Read index.yaml

Read `.learnings/index.yaml`. Format:

```yaml
version: 1
last_rebuilt: <ISO timestamp>
active_count: <N>
archived_count: <M>

entries:
  - id: <string>
    domain: <string>
    one_liner: "<string>"
    created: <date>
```

`entries:` contains ONLY active learnings. Archived learnings exist only as `.md` files with `status: archived` in frontmatter.

**If index.yaml does not exist:**
Report: `No index found. Run the learnings observer or create learnings manually.`
Stop. Unless `--all` was specified — in that case, skip to Step 3 and scan .md files directly.

**If index.yaml exists but entries is empty or `[]`:**
- If `--all` was specified: do NOT stop here. Proceed to Step 3 to scan for archived entries.
- If `archived_count > 0` and `--all` was NOT specified: Report: `No active learnings. <archived_count> archived learnings exist — use /recall-learnings --all to view them.` Stop.
- Otherwise: Report: `No active learnings found.` Stop.

### Step 3 — Apply argument filter

**No argument (list mode):**
Show all active entries from `entries:` as a one-liner list, grouped by domain.
If `archived_count > 0`, append: `Note: <archived_count> archived learnings not shown. Use /recall-learnings --all to include them.`

**Argument is `--all` (standalone, no domain/keyword):**
This is a standalone list mode invocation that includes archived entries:
1. Load active entries from index (same as no-argument list mode).
2. Scan `.learnings/*.md` for files with `status: archived` in frontmatter. Parse their `id`, `domain`, and extract a one_liner.
3. Present both active and archived entries in list mode. Label archived entries with `[archived]`.
4. If both active and archived are zero: report `No learnings found (0 active, 0 archived)`.

**Argument is a domain name or keyword:**
- First check: does the argument exactly match any `domain` value in the entries? If yes -> domain filter (Step 4a).
- If no exact domain match: treat as keyword -> search for argument as substring in `one_liner` values (case-insensitive). If matches found -> keyword filter (Step 4b).
- If no domain match and no one_liner match:
  - Single word or hyphenated: report `No learnings found for domain: <argument>`
  - Otherwise: report `No learnings found matching: <argument>`
  Stop. Do not report empty results silently.

**Note:** Domains are expected to be single words or hyphenated terms (e.g., `tooling`, `architecture`, `config`). Multi-word arguments are treated as keyword searches.

### Step 4a — Domain filter: load full content

For each entry matching the domain:
1. Scan `.learnings/*.md` for a file whose frontmatter `id` field matches the entry id. Filenames use `YYYY-MM-DD_slug.md` format — do not assume `<id>.md`.
2. **If multiple files match the same id:** Use the first match. This is a known limitation.
3. **If no matching file is found:** Report: `Learning file missing: <id>` (do not skip silently, do not crash). Continue to next entry.
4. Read the file and include the full markdown body in output.

Group all results under a domain heading.

If `--all` was also specified, scan `.learnings/*.md` for archived files with matching domain and include them labeled `[archived]`.

### Step 4b — Keyword filter: load full content

For each entry where `one_liner` contains the keyword (case-insensitive):
1. Scan `.learnings/*.md` for a file whose frontmatter `id` field matches the entry id.
2. **If multiple files match the same id:** Use the first match.
3. **If no matching file is found:** Report: `Learning file missing: <id>` (do not skip silently). Continue to next entry.
4. Read the file and include the full markdown body in output.

If `--all` was also specified, also scan `.learnings/*.md` for archived files whose `one_liner` (extracted from body) contains the keyword, and include them labeled `[archived]`.

Note: keyword search only covers `one_liner` values from the index, not full body text. A relevant learning whose keyword appears only in the body will not be found. Try a broader search term if results seem incomplete.

### Step 5 — Present results

**List mode (no argument):**

```
Active learnings (N total):

[domain-a]
  - <id>: <one_liner>
  - <id>: <one_liner>

[domain-b]
  - <id>: <one_liner>

Note: M archived learnings not shown. Use /recall-learnings --all to include them.
```

**List mode with --all:**

```
All learnings (N active, M archived):

[domain-a]
  - <id>: <one_liner>
  - <id>: <one_liner> [archived]

[domain-b]
  - <id>: <one_liner>
```

**Full content mode (domain or keyword filter):**

```
Learnings matching <argument> (N results):

--- <id> [domain] ---
<full markdown content of the .md file>

--- <id> [domain] ---
<full markdown content of the .md file>
```

**No results:** Always report explicitly — never return blank output.

## Error Handling (mandatory)

| Condition | Required output |
|---|---|
| `.learnings/` directory absent | `No learnings directory found in this project` |
| No matching domain | `No learnings found for domain: <argument>` |
| No keyword matches | `No learnings found matching: <argument>` |
| .md file missing for index entry | `Learning file missing: <id>` (continue, do not stop) |
| Active = 0, archived > 0, no --all | Show count, suggest --all |
| --all with 0 active + 0 archived | `No learnings found (0 active, 0 archived)` |

## Known Limitations

1. Keyword search covers `one_liner` only — learnings with keyword only in body text will not be found.
2. `--all` requires scanning all `.md` files and parsing frontmatter — may be slow on large sets (100+ files).
3. File lookup scans all `.md` files for matching frontmatter `id` — O(N) per result.
