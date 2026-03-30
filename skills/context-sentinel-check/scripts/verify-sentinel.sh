#!/usr/bin/env sh
set -eu

answer="$(cat)"
sentinel="${CONTEXT_SENTINEL:-}"

if [ -z "$sentinel" ]; then
  echo "SKIP"
  exit 0
fi

if printf '%s' "$answer" | grep -F -- "$sentinel" >/dev/null 2>&1; then
  echo "PASS"
  exit 0
fi

echo "FAIL"
exit 1
