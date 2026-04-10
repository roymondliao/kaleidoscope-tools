#!/usr/bin/env sh
set -eu

answer="$(cat | tr -d '[:space:]')"
hash_file="$HOME/.claude/runtime/session-sentinel.hash"

if [ ! -f "$hash_file" ]; then
  echo "SKIP"
  exit 0
fi

answer_hash="$(printf '%s' "$answer" | shasum -a 256 | cut -d' ' -f1)"
stored_hash="$(cat "$hash_file" | tr -d '[:space:]')"

if [ "$answer_hash" = "$stored_hash" ]; then
  echo "PASS"
  exit 0
fi

echo "FAIL"
exit 1
