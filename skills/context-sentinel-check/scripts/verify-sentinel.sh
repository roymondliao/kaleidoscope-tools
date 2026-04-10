#!/usr/bin/env sh
set -eu

answer="$(cat | tr -d '[:space:]')"
sentinel_dir="$HOME/.claude/runtime/sentinel"

if [ ! -d "$sentinel_dir" ] || [ -z "$(ls "$sentinel_dir"/*.hash 2>/dev/null)" ]; then
  echo "SKIP"
  exit 0
fi

answer_hash="$(printf '%s' "$answer" | shasum -a 256 | cut -d' ' -f1)"

for hash_file in "$sentinel_dir"/*.hash; do
  [ -f "$hash_file" ] || continue
  stored_hash="$(cat "$hash_file" | tr -d '[:space:]')"
  if [ "$answer_hash" = "$stored_hash" ]; then
    echo "PASS"
    exit 0
  fi
done

echo "FAIL"
exit 1
