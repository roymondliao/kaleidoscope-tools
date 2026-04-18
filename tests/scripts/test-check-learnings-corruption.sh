#!/usr/bin/env bash
# Tests for corruption signature detection in hooks/scripts/check-learnings.py
# Death tests: each signature path must fire in the expected condition
# and must NOT fire in the baseline healthy state.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VENV_PYTHON="${REPO_ROOT}/.venv/bin/python3"
CHECK_PY="${REPO_ROOT}/hooks/scripts/check-learnings.py"

pass_count=0
fail_count=0
pass() { echo "  PASS: $1"; pass_count=$((pass_count+1)); }
fail() { echo "  FAIL: $1" >&2; fail_count=$((fail_count+1)); }

setup_fixture() {
    # Creates an empty .learnings/ dir under a temp path and minimal index.yaml
    local tmpdir
    tmpdir=$(mktemp -d -t cl-corruption-XXXXXX)
    mkdir -p "${tmpdir}/.learnings"
    cat > "${tmpdir}/.learnings/index.yaml" <<EOF
version: 1
last_rebuilt: 2026-04-17T10:00:00Z
active_count: 0
archived_count: 0
entries: []
EOF
    echo "$tmpdir"
}

write_learning() {
    # $1=dir $2=id $3=status $4=classification $5=created $6=last_validated
    local dir="$1" id="$2" status="$3" cls="$4" created="$5" last_val="$6"
    cat > "${dir}/.learnings/${id}.md" <<EOF
---
id: ${id}
domain: tooling
trigger: "When ${id}"
created: ${created}
last_validated: ${last_val}
status: ${status}
source_session: test
classification: ${cls}
---

# ${id}
## What went wrong
Test body for ${id}.

## Correct approach
Fix for ${id}.
EOF
}

run_check() {
    "$VENV_PYTHON" "$CHECK_PY" "${1}/.learnings/index.yaml" "${1}/.learnings"
}

# ── baseline: no signatures on healthy state ────────────────────────────────

echo "Test 1: baseline healthy state (no corruption)"
dir=$(setup_fixture)
trap "rm -rf $dir" EXIT

write_learning "$dir" "2026-04-17_a" "active" "new" "2026-04-17" "2026-04-17"
# Need index to match
cat > "${dir}/.learnings/index.yaml" <<EOF
version: 1
last_rebuilt: 2026-04-17T10:00:00Z
active_count: 1
archived_count: 0
entries:
  - id: 2026-04-17_a
    domain: tooling
    one_liner: "Test"
    created: 2026-04-17
EOF

output=$(run_check "$dir")
if echo "$output" | grep -q "CORRUPTION:"; then
    fail "baseline should have no corruption signals; got: $(echo "$output" | grep CORRUPTION)"
else
    pass "baseline emits no corruption signals"
fi
rm -rf "$dir"

# ── test 2: monotone_growth fires with 10+ active and 0 invalidated ─────────

echo "Test 2: monotone_growth signal"
dir=$(setup_fixture)

entries_yaml=""
for i in $(seq 1 11); do
    id="2026-04-17_grow-${i}"
    write_learning "$dir" "$id" "active" "new" "2026-04-17" "2026-04-17"
    entries_yaml="${entries_yaml}  - id: ${id}
    domain: tooling
    one_liner: \"grow ${i}\"
    created: 2026-04-17
"
done
cat > "${dir}/.learnings/index.yaml" <<EOF
version: 1
last_rebuilt: 2026-04-17T10:00:00Z
active_count: 11
archived_count: 0
entries:
${entries_yaml}
EOF

output=$(run_check "$dir")
if echo "$output" | grep -q "CORRUPTION:monotone_growth"; then
    pass "monotone_growth fires at 11 active / 0 invalidated"
else
    fail "expected CORRUPTION:monotone_growth; output: $output"
fi
rm -rf "$dir"

# ── test 3: monotone_growth does NOT fire when some are invalidated ────────

echo "Test 3: monotone_growth suppressed by invalidation"
dir=$(setup_fixture)

for i in $(seq 1 10); do
    write_learning "$dir" "2026-04-17_ok-${i}" "active" "new" "2026-04-17" "2026-04-17"
done
write_learning "$dir" "2026-04-17_inv-1" "invalidated" "supersedes:2026-04-17_ok-1" "2026-04-17" "2026-04-17"

cat > "${dir}/.learnings/index.yaml" <<EOF
version: 1
last_rebuilt: 2026-04-17T10:00:00Z
active_count: 10
archived_count: 0
entries:
  - id: 2026-04-17_ok-1
    domain: tooling
    one_liner: "x"
    created: 2026-04-17
EOF

output=$(run_check "$dir")
if echo "$output" | grep -q "CORRUPTION:monotone_growth"; then
    fail "monotone_growth should NOT fire when invalidations exist; output: $output"
else
    pass "monotone_growth suppressed by presence of invalidated learning"
fi
rm -rf "$dir"

# ── test 4: stale_learnings signal fires when majority stale ───────────────

echo "Test 4: stale_learnings signal"
dir=$(setup_fixture)

# Past date (>90 days ago) → 2026-01-01 (Jan 2026, so relative to Apr 2026 is ~107 days)
for i in $(seq 1 4); do
    write_learning "$dir" "2026-01-01_stale-${i}" "active" "new" "2026-01-01" "2026-01-01"
done
# One recent
write_learning "$dir" "2026-04-17_fresh-1" "active" "new" "2026-04-17" "2026-04-17"

cat > "${dir}/.learnings/index.yaml" <<EOF
version: 1
last_rebuilt: 2026-04-17T10:00:00Z
active_count: 5
archived_count: 0
entries:
  - id: 2026-04-17_fresh-1
    domain: tooling
    one_liner: "fresh"
    created: 2026-04-17
EOF

output=$(run_check "$dir")
if echo "$output" | grep -q "CORRUPTION:stale_learnings"; then
    pass "stale_learnings fires when >50% stale"
else
    fail "expected CORRUPTION:stale_learnings; output: $output"
fi
rm -rf "$dir"

# ── test 5: empty state (no learnings) → no corruption ─────────────────────

echo "Test 5: empty state → no corruption"
dir=$(setup_fixture)

output=$(run_check "$dir")
if echo "$output" | grep -q "CORRUPTION:"; then
    fail "empty state should not emit corruption; output: $output"
else
    pass "empty state emits no corruption signals"
fi
rm -rf "$dir"

# ── summary ─────────────────────────────────────────────────────────────────

trap - EXIT
echo ""
echo "=== RESULTS ==="
echo "  Passed: $pass_count"
echo "  Failed: $fail_count"

if [ "$fail_count" -gt 0 ]; then
    echo "FAILED"
    exit 1
fi
echo "All tests passed."
