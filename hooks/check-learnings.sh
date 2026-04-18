#!/usr/bin/env bash
# check-learnings.sh — SessionStart hook: inject project learnings into context.
# Thin wrapper: finds Python, delegates to hooks/scripts/check-learnings.py,
# formats output as Claude Code hook JSON.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── find python ──────────────────────────────────────────────────────────────

_find_python() {
    local dir="$SCRIPT_DIR"
    local depth=0
    while [ "$depth" -lt 5 ]; do
        if [ -x "${dir}/.venv/bin/python3" ]; then
            printf '%s/.venv/bin/python3' "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
        (( depth++ )) || true  # prevent set -e on arithmetic zero
    done
    command -v python3 >/dev/null 2>&1 && printf 'python3' && return 0
    return 1
}

PYTHON=$(_find_python) || exit 0

# ── guards ───────────────────────────────────────────────────────────────────

[ -z "${CLAUDE_PROJECT_DIR:-}" ] && exit 0
[ ! -d "${CLAUDE_PROJECT_DIR}/.learnings" ] && exit 0
[ ! -f "${CLAUDE_PROJECT_DIR}/.learnings/index.yaml" ] && exit 0

# ── helpers ──────────────────────────────────────────────────────────────────

escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

inject_message() {
    local escaped
    escaped=$(escape_for_json "$1")
    printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$escaped"
}

# ── delegate to Python ───────────────────────────────────────────────────────

py_output=$("$PYTHON" "${SCRIPT_DIR}/scripts/check-learnings.py" \
    "${CLAUDE_PROJECT_DIR}/.learnings/index.yaml" \
    "${CLAUDE_PROJECT_DIR}/.learnings" 2>/dev/null) || {
    inject_message "Project Learnings: INDEX MALFORMED (parse error). Rebuild index.yaml."
    exit 0
}

# ── parse line protocol ──────────────────────────────────────────────────────

status="" entry_count=0 missing_count=0
got_count=false got_missing=false
entries_output=""
corruption_output=""

while IFS= read -r line; do
    case "$line" in
        STATUS:*)        status="${line#STATUS:}" ;;
        COUNT:*)         entry_count="${line#COUNT:}"; got_count=true ;;
        MISSING_COUNT:*) missing_count="${line#MISSING_COUNT:}"; got_missing=true ;;
        ENTRY:*)
            data="${line#ENTRY:}"
            domain="${data%%|*}"
            one_liner="${data#*|}"
            entries_output="${entries_output}- [${domain}] ${one_liner}\n"
            ;;
        CORRUPTION:*)
            data="${line#CORRUPTION:}"
            sig="${data%%|*}"
            val="${data#*|}"
            corruption_output="${corruption_output}  [${sig}] ${val}\n"
            ;;
    esac
done <<< "$py_output"

# ── validate + build message ─────────────────────────────────────────────────

case "$status" in
    ok)
        [ "$got_count" = "false" ] || [ "$got_missing" = "false" ] && {
            inject_message "Project Learnings: INDEX MALFORMED (incomplete parse). Rebuild index.yaml."
            exit 0
        }
        valid=$(( entry_count - missing_count ))
        [ "$valid" -le 0 ] && [ "$missing_count" -gt 0 ] && {
            inject_message "Project Learnings: all ${entry_count} entries missing backing files. Rebuild index.yaml."
            exit 0
        }
        warning=""
        [ "$missing_count" -gt 0 ] && warning="\nWARNING: ${missing_count} entries missing .md files."

        corruption_warning=""
        if [ -n "$corruption_output" ]; then
            corruption_warning="\nCorruption signals detected (run /review-learnings):\n${corruption_output}"
        fi

        inject_message "Project Learnings (${valid} active):\n${entries_output}${warning}${corruption_warning}Use /recall-learnings to query full details."
        ;;
    empty)        exit 0 ;;
    missing_entries_key)
        inject_message "Project Learnings: INDEX INCOMPLETE (missing 'entries' key). Rebuild index.yaml."
        ;;
    *)
        inject_message "Project Learnings: INDEX MALFORMED (parse error). Rebuild index.yaml."
        ;;
esac

exit 0
