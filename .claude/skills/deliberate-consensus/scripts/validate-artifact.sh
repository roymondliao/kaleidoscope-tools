#!/bin/bash
# Validates that a deliberation artifact contains required sections.
# Usage: validate-artifact.sh <stage> <file-path>
# Returns: 0 if valid, 1 if missing sections (prints missing sections to stderr)

STAGE="$1"
FILE="$2"

if [ ! -f "$FILE" ]; then
  echo "ERROR: File not found: $FILE" >&2
  exit 1
fi

MISSING=()

check_section() {
  if ! grep -q "^## $1\|^### $1" "$FILE"; then
    MISSING+=("$1")
  fi
}

case "$STAGE" in
  1)
    check_section "Thesis"
    check_section "Recommendation"
    check_section "Assumptions"
    check_section "Evidence"
    check_section "Strongest Reasons"
    check_section "Risk If Wrong"
    check_section "Argument Strength"
    ;;
  2)
    # Check that at least 2 "Attack on" sections exist
    ATTACK_COUNT=$(grep -c "^### Attack on\|^## Attack on" "$FILE")
    if [ "$ATTACK_COUNT" -lt 2 ]; then
      MISSING+=("Attack on (need at least 2, found $ATTACK_COUNT)")
    fi
    ;;
  3)
    check_section "Prior Position"
    check_section "Current Position"
    check_section "Changed"
    check_section "Attacks Survived"
    check_section "Attacks Not Answered"
    ;;
  4)
    check_section "Ruling"
    check_section "Rationale"
    check_section "Winning Case"
    check_section "Minority Report"
    check_section "Unresolved Questions"
    check_section "Consensus Type"
    check_section "Next Actions"
    ;;
  *)
    echo "ERROR: Unknown stage: $STAGE (use 1, 2, 3, or 4)" >&2
    exit 1
    ;;
esac

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "INVALID: Missing sections in $FILE:" >&2
  for section in "${MISSING[@]}"; do
    echo "  - $section" >&2
  done
  exit 1
fi

echo "VALID: $FILE"
exit 0
