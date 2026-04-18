#!/usr/bin/env bash
# observe-learnings.sh — UserPromptSubmit hook: capture user messages for learning analysis.
# Thin wrapper: finds Python, pipes stdin to hooks/scripts/observe-learnings.py.
# No output (observation hooks should be invisible to the user).
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
        (( depth++ )) || true
    done
    command -v python3 >/dev/null 2>&1 && printf 'python3' && return 0
    return 1
}

PYTHON=$(_find_python) || exit 0

# ── delegate to Python (pipe stdin through) ──────────────────────────────────

exec "$PYTHON" "${SCRIPT_DIR}/scripts/observe-learnings.py"
