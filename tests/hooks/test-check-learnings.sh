#!/usr/bin/env bash
# Tests for hooks/check-learnings
# Death tests run FIRST (silent failure paths), then unit tests.
# Run with: bash tests/hooks/test-check-learnings.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

HOOK="${REPO_ROOT}/hooks/check-learnings.sh"
VENV_PYTHON="${REPO_ROOT}/.venv/bin/python3"

# ── helpers ──────────────────────────────────────────────────────────────────

pass_count=0
fail_count=0

pass() {
    echo "  PASS: $1"
    # NOTE: (( expr )) returns exit code 1 when result is 0, which triggers set -e.
    # || true prevents that from aborting the test runner.
    (( pass_count++ )) || true
}

fail() {
    echo "  FAIL: $1"
    echo "        $2"
    # NOTE: same arithmetic-zero guard as above.
    (( fail_count++ )) || true
}

# Shared temp file for stderr capture (mktemp avoids collisions in parallel runs)
STDERR_TMP=$(mktemp)
# Clean up temp file on exit
trap 'rm -f "$STDERR_TMP"' EXIT

# Run hook with a given CLAUDE_PROJECT_DIR; capture stdout, stderr, and exit code.
# Usage: run_hook <tmpdir>
# Sets: hook_stdout, hook_stderr, hook_exit
run_hook() {
    local dir="$1"
    hook_stdout=""
    hook_stderr=""
    hook_exit=0
    hook_stdout=$(CLAUDE_PROJECT_DIR="$dir" bash "$HOOK" 2>"$STDERR_TMP") || hook_exit=$?
    hook_stderr=$(cat "$STDERR_TMP" 2>/dev/null || true)
}

# ── pre-flight ────────────────────────────────────────────────────────────────

if [ ! -f "$HOOK" ]; then
    echo "FATAL: hook does not exist at $HOOK"
    echo "       Run tests after implementing the hook."
    exit 1
fi

if [ ! -x "$VENV_PYTHON" ]; then
    echo "FATAL: venv python not found at $VENV_PYTHON"
    exit 1
fi

# ── DEATH TESTS (silent failure paths) ───────────────────────────────────────
# These test paths where the hook could fail silently and give the agent
# no indication that the learnings system is broken.

echo ""
echo "=== DEATH TESTS ==="

# Death test 1: malformed index.yaml — hook must NOT exit 0 silently
# Silent failure: agent starts session without learnings and has no idea why.
# The hook MUST inject an error message so the agent knows the index is broken.
echo ""
echo "Death test 1: malformed index.yaml → must inject error, not exit silently"
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/.learnings"
printf 'version: 1\nentries: [\n  broken yaml with no closing bracket\n' > "$tmpdir/.learnings/index.yaml"
run_hook "$tmpdir"
rm -rf "$tmpdir"

if [ "$hook_exit" -ne 0 ]; then
    fail "malformed index" "hook exited with $hook_exit (should exit 0 and inject error message into context)"
elif [ -z "$hook_stdout" ]; then
    fail "malformed index" "hook exited 0 with no output — silent failure! agent gets no error notification"
elif echo "$hook_stdout" | "$VENV_PYTHON" -c "import sys,json; d=json.load(sys.stdin); msg=d['hookSpecificOutput']['additionalContext']; sys.exit(0 if 'MALFORMED' in msg.upper() else 1)" 2>/dev/null; then
    pass "malformed index → injects MALFORMED error message into additionalContext"
else
    fail "malformed index" "output exists but does not contain MALFORMED: $(echo "$hook_stdout" | head -3)"
fi

# Death test 2: index.yaml exists with entries pointing to deleted .md files
# Silent failure: agent sees stale one-liners for learnings that no longer exist.
# The hook must warn rather than silently inject stale data.
echo ""
echo "Death test 2: entries pointing to deleted .md files → must warn in output, not silently inject stale data"
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/.learnings"
cat > "$tmpdir/.learnings/index.yaml" << 'EOF'
version: 1
last_rebuilt: 2026-04-15T10:00:00Z
active_count: 2
archived_count: 0

entries:
  - id: 2026-04-15_ghost-entry
    domain: testing
    one_liner: "This entry references a deleted file"
    created: 2026-04-15
  - id: 2026-04-15_another-ghost
    domain: database
    one_liner: "This one is also missing its .md file"
    created: 2026-04-15
EOF
# NOTE: deliberately NOT creating the .md files — testing stale entries
run_hook "$tmpdir"
rm -rf "$tmpdir"

if [ "$hook_exit" -ne 0 ]; then
    fail "deleted .md files" "hook exited with $hook_exit instead of 0"
elif [ -z "$hook_stdout" ]; then
    fail "deleted .md files" "hook exited 0 with no output — stale entries silently ignored"
elif echo "$hook_stdout" | "$VENV_PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
msg = d['hookSpecificOutput']['additionalContext']
# Must include warning about missing files, not silently show stale entries
has_warning = any(w in msg.upper() for w in ['WARN', 'MISSING', 'NOT FOUND', 'STALE', 'GHOST'])
sys.exit(0 if has_warning else 1)
" 2>/dev/null; then
    pass "deleted .md files → warning injected into additionalContext"
else
    # Check if it silently injected stale data (the worst case)
    if echo "$hook_stdout" | "$VENV_PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
msg = d['hookSpecificOutput']['additionalContext']
sys.exit(0 if 'ghost-entry' in msg or 'another-ghost' in msg else 1)
" 2>/dev/null; then
        fail "deleted .md files" "SILENT STALE DATA: hook injected stale entries as if they were valid"
    else
        fail "deleted .md files" "output exists but no warning found and no stale data injected: $(echo "$hook_stdout" | head -3)"
    fi
fi

# Death test 3: CLAUDE_PROJECT_DIR is not set — must exit 0 with no output
# Silent failure mode here is the CORRECT behavior (no project dir = not applicable)
# but we must verify it truly exits 0 and produces no output (not a crash-exit-0).
# IMPORTANT: explicitly unset CLAUDE_PROJECT_DIR to prevent inherited env from the
# test runner (e.g., running inside Claude Code) from causing a false pass.
echo ""
echo "Death test 3: CLAUDE_PROJECT_DIR unset → exit 0, no output (not-applicable case)"
hook_stdout=""
hook_exit=0
hook_stdout=$(env -u CLAUDE_PROJECT_DIR bash "$HOOK" 2>"$STDERR_TMP") || hook_exit=$?
hook_stderr=$(cat "$STDERR_TMP" 2>/dev/null || true)

if [ "$hook_exit" -ne 0 ]; then
    fail "CLAUDE_PROJECT_DIR unset" "hook exited with $hook_exit instead of 0"
elif [ -n "$hook_stdout" ]; then
    fail "CLAUDE_PROJECT_DIR unset" "hook produced output when no project dir set: $hook_stdout"
else
    pass "CLAUDE_PROJECT_DIR unset → exit 0, no output"
fi

# Death test 4: entries list is empty → must exit 0 with no output
# Silent failure: if hook injects empty list JSON, it wastes tokens and
# signals to agent that learnings exist when there are none.
echo ""
echo "Death test 4: entries empty in index.yaml → exit 0, no output (zero token cost)"
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/.learnings"
cat > "$tmpdir/.learnings/index.yaml" << 'EOF'
version: 1
last_rebuilt: 2026-04-15T10:00:00Z
active_count: 0
archived_count: 0

entries: []
EOF
run_hook "$tmpdir"
rm -rf "$tmpdir"

if [ "$hook_exit" -ne 0 ]; then
    fail "empty entries" "hook exited with $hook_exit instead of 0"
elif [ -n "$hook_stdout" ]; then
    fail "empty entries" "hook produced output for empty entries (wastes tokens): $hook_stdout"
else
    pass "empty entries → exit 0, no output"
fi

# Death test 5: index.yaml exists but entries key is missing entirely
# Silent failure: PyYAML returns None for missing key; hook might crash or silently skip.
# The injected message must be INCOMPLETE (not MALFORMED) — structurally valid YAML
# but missing required key is a different failure mode from a parse error.
echo ""
echo "Death test 5: index.yaml missing 'entries' key entirely → inject INCOMPLETE error (not parse error)"
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/.learnings"
cat > "$tmpdir/.learnings/index.yaml" << 'EOF'
version: 1
last_rebuilt: 2026-04-15T10:00:00Z
active_count: 0
archived_count: 0
EOF
# no 'entries:' key at all
run_hook "$tmpdir"
rm -rf "$tmpdir"

if [ "$hook_exit" -ne 0 ]; then
    fail "missing entries key" "hook exited with $hook_exit (should exit 0 with error message)"
elif [ -z "$hook_stdout" ]; then
    fail "missing entries key" "hook exited 0 silently — missing entries key ignored without warning"
elif echo "$hook_stdout" | "$VENV_PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
msg = d['hookSpecificOutput']['additionalContext']
# Must say INCOMPLETE (missing key), NOT just MALFORMED (which implies parse error)
sys.exit(0 if 'INCOMPLETE' in msg.upper() else 1)
" 2>/dev/null; then
    pass "missing entries key → injects INCOMPLETE error (distinct from parse-error MALFORMED)"
else
    fail "missing entries key" "output exists but no INCOMPLETE in message: $(echo "$hook_stdout" | head -3)"
fi

# ── UNIT TESTS ────────────────────────────────────────────────────────────────

echo ""
echo "=== UNIT TESTS ==="

# Unit test 1: .learnings/ directory does not exist → exit 0, no output
echo ""
echo "Unit test 1: .learnings/ dir missing → exit 0, no output"
tmpdir=$(mktemp -d)
# do NOT create .learnings/ inside tmpdir
run_hook "$tmpdir"
rm -rf "$tmpdir"

if [ "$hook_exit" -ne 0 ]; then
    fail ".learnings/ missing" "hook exited with $hook_exit instead of 0"
elif [ -n "$hook_stdout" ]; then
    fail ".learnings/ missing" "hook produced output when dir missing: $hook_stdout"
else
    pass ".learnings/ dir missing → exit 0, no output"
fi

# Unit test 2: .learnings/ exists but no index.yaml → exit 0, no output
echo ""
echo "Unit test 2: .learnings/ exists, no index.yaml → exit 0, no output"
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/.learnings"
run_hook "$tmpdir"
rm -rf "$tmpdir"

if [ "$hook_exit" -ne 0 ]; then
    fail "no index.yaml" "hook exited with $hook_exit instead of 0"
elif [ -n "$hook_stdout" ]; then
    fail "no index.yaml" "hook produced output when index missing: $hook_stdout"
else
    pass "no index.yaml → exit 0, no output"
fi

# Unit test 3: valid index with entries where .md files exist → inject summary
echo ""
echo "Unit test 3: valid index with 3 entries (all .md files exist) → inject formatted summary"
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/.learnings"

# Create .md files
touch "$tmpdir/.learnings/2026-04-15_jest-vitest.md"
touch "$tmpdir/.learnings/2026-04-15_migration-no-lock.md"
touch "$tmpdir/.learnings/2026-04-15_oauth-token.md"

cat > "$tmpdir/.learnings/index.yaml" << 'EOF'
version: 1
last_rebuilt: 2026-04-15T10:00:00Z
active_count: 3
archived_count: 0

entries:
  - id: 2026-04-15_jest-vitest
    domain: testing
    one_liner: "This project uses Vitest not Jest"
    created: 2026-04-15
  - id: 2026-04-15_migration-no-lock
    domain: database
    one_liner: "DB migrations cannot use table locks"
    created: 2026-04-15
  - id: 2026-04-15_oauth-token
    domain: auth
    one_liner: "OAuth tokens expire after 1h not 24h"
    created: 2026-04-15
EOF
run_hook "$tmpdir"
rm -rf "$tmpdir"

if [ "$hook_exit" -ne 0 ]; then
    fail "3 valid entries" "hook exited with $hook_exit instead of 0"
elif [ -z "$hook_stdout" ]; then
    fail "3 valid entries" "hook produced no output — learnings not injected"
elif echo "$hook_stdout" | "$VENV_PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
out = d['hookSpecificOutput']
assert out['hookEventName'] == 'SessionStart', 'wrong hookEventName'
msg = out['additionalContext']
assert 'Project Learnings' in msg, 'missing header'
assert '3' in msg, 'count 3 not mentioned'
assert 'Vitest' in msg or 'testing' in msg, 'testing entry missing'
assert 'migrations' in msg.lower() or 'database' in msg or 'DB' in msg, 'database entry missing'
assert 'recall' in msg.lower() or '/samsara' in msg, 'recall hint missing'
print('all assertions passed')
" 2>/dev/null; then
    pass "3 valid entries → formatted summary injected with count and one_liners"
else
    fail "3 valid entries" "output malformed or assertions failed: $(echo "$hook_stdout" | head -5)"
fi

# Unit test 4: valid JSON output structure
echo ""
echo "Unit test 4: output is valid JSON with correct structure"
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/.learnings"
touch "$tmpdir/.learnings/2026-04-15_test.md"
cat > "$tmpdir/.learnings/index.yaml" << 'EOF'
version: 1
last_rebuilt: 2026-04-15T10:00:00Z
active_count: 1
archived_count: 0

entries:
  - id: 2026-04-15_test
    domain: testing
    one_liner: "Test one liner"
    created: 2026-04-15
EOF
run_hook "$tmpdir"
rm -rf "$tmpdir"

if [ "$hook_exit" -ne 0 ]; then
    fail "JSON structure" "hook exited $hook_exit"
elif echo "$hook_stdout" | "$VENV_PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
assert 'hookSpecificOutput' in d
assert 'hookEventName' in d['hookSpecificOutput']
assert 'additionalContext' in d['hookSpecificOutput']
assert d['hookSpecificOutput']['hookEventName'] == 'SessionStart'
" 2>/dev/null; then
    pass "output is valid JSON with hookSpecificOutput.hookEventName and additionalContext"
else
    fail "JSON structure" "JSON invalid or missing required keys: $(echo "$hook_stdout" | head -3)"
fi

# Unit test 5: one_liner with special JSON characters (quotes, backslashes, newlines)
echo ""
echo "Unit test 5: one_liner with JSON special chars → output must still be valid JSON"
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/.learnings"
touch "$tmpdir/.learnings/2026-04-15_special.md"
cat > "$tmpdir/.learnings/index.yaml" << 'EOF'
version: 1
last_rebuilt: 2026-04-15T10:00:00Z
active_count: 1
archived_count: 0

entries:
  - id: 2026-04-15_special
    domain: testing
    one_liner: "Use \"npx vitest\" not \"jest\" — see README.md"
    created: 2026-04-15
EOF
run_hook "$tmpdir"
rm -rf "$tmpdir"

if [ "$hook_exit" -ne 0 ]; then
    fail "special chars" "hook exited $hook_exit"
elif echo "$hook_stdout" | "$VENV_PYTHON" -c "import sys, json; json.load(sys.stdin); print('valid JSON')" 2>/dev/null; then
    pass "one_liner with quotes → output is still valid JSON"
else
    fail "special chars" "output is not valid JSON — special chars broke JSON: $(echo "$hook_stdout" | head -3)"
fi

# Unit test 6: exactly one entry that has its .md file present → no warning
echo ""
echo "Unit test 6: single valid entry → inject without warning"
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/.learnings"
touch "$tmpdir/.learnings/2026-04-15_single.md"
cat > "$tmpdir/.learnings/index.yaml" << 'EOF'
version: 1
last_rebuilt: 2026-04-15T10:00:00Z
active_count: 1
archived_count: 0

entries:
  - id: 2026-04-15_single
    domain: infra
    one_liner: "Always use terraform plan before apply"
    created: 2026-04-15
EOF
run_hook "$tmpdir"
rm -rf "$tmpdir"

if [ "$hook_exit" -ne 0 ]; then
    fail "single entry" "hook exited $hook_exit"
elif [ -z "$hook_stdout" ]; then
    fail "single entry" "hook produced no output"
elif echo "$hook_stdout" | "$VENV_PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
msg = d['hookSpecificOutput']['additionalContext']
assert 'terraform' in msg.lower() or 'infra' in msg.lower(), 'entry content missing'
# Should NOT contain any warning about stale/missing
has_warning = any(w in msg.upper() for w in ['WARN', 'MISSING', 'NOT FOUND', 'STALE'])
assert not has_warning, f'unexpected warning in clean entry: {msg}'
" 2>/dev/null; then
    pass "single valid entry → injected without warning"
else
    fail "single entry" "output issue: $(echo "$hook_stdout" | head -3)"
fi

# Unit test 7: mixed — some entries have .md files, some don't
echo ""
echo "Unit test 7: mixed entries (1 valid, 1 missing .md) → warn about missing, still inject valid"
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/.learnings"
touch "$tmpdir/.learnings/2026-04-15_present.md"
# 2026-04-15_absent.md intentionally not created
cat > "$tmpdir/.learnings/index.yaml" << 'EOF'
version: 1
last_rebuilt: 2026-04-15T10:00:00Z
active_count: 2
archived_count: 0

entries:
  - id: 2026-04-15_present
    domain: testing
    one_liner: "Use Vitest not Jest"
    created: 2026-04-15
  - id: 2026-04-15_absent
    domain: database
    one_liner: "Stale entry with no backing file"
    created: 2026-04-15
EOF
run_hook "$tmpdir"
rm -rf "$tmpdir"

if [ "$hook_exit" -ne 0 ]; then
    fail "mixed entries" "hook exited $hook_exit"
elif [ -z "$hook_stdout" ]; then
    fail "mixed entries" "hook produced no output"
elif echo "$hook_stdout" | "$VENV_PYTHON" -c "
import sys, json
d = json.load(sys.stdin)
msg = d['hookSpecificOutput']['additionalContext']
# Must contain valid entry content
assert 'Vitest' in msg or 'testing' in msg, 'valid entry missing from output'
# Must warn about the missing file
has_warning = any(w in msg.upper() for w in ['WARN', 'MISSING', 'NOT FOUND', 'STALE', 'GHOST', '1 MISSING'])
assert has_warning, f'no warning for missing .md file: {msg}'
" 2>/dev/null; then
    pass "mixed entries → valid entry injected + warning about missing .md file"
else
    fail "mixed entries" "output issue: $(echo "$hook_stdout" | head -5)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "=== RESULTS ==="
echo "  Passed: $pass_count"
echo "  Failed: $fail_count"
echo ""

if [ "$fail_count" -gt 0 ]; then
    exit 1
else
    echo "All tests passed."
    exit 0
fi
