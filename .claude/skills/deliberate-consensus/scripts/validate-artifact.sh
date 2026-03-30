#!/bin/bash
# Validates that a deliberation artifact contains required sections and frontmatter fields.
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

# Extract YAML frontmatter (between first two --- lines)
check_frontmatter_field() {
  local field="$1"
  local valid_values="$2"  # pipe-separated, e.g. "accept|reject|revise|investigate"
  # Check field exists in frontmatter
  local value
  value=$(sed -n '/^---$/,/^---$/p' "$FILE" | grep "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" | tr -d '"' | tr -d "'")
  if [ -z "$value" ]; then
    MISSING+=("frontmatter field '${field}'")
    return
  fi
  # Check value is valid if valid_values provided
  if [ -n "$valid_values" ]; then
    if ! echo "$value" | grep -qE "^(${valid_values})$"; then
      MISSING+=("frontmatter '${field}' has invalid value '${value}' (expected: ${valid_values})")
    fi
  fi
}

case "$STAGE" in
  1)
    check_section "Thesis"
    check_section "Recommendation"
    check_section "Key Findings"
    check_section "Assumptions"
    check_section "Risk If Wrong"
    check_section "Weakest Point"
    # Frontmatter validation
    check_frontmatter_field "recommendation" "accept|reject|revise|investigate"
    ;;
  2)
    # Check that at least 2 "Attack on" sections exist
    ATTACK_COUNT=$(grep -c "^### Attack on\|^## Attack on" "$FILE")
    if [ "$ATTACK_COUNT" -lt 2 ]; then
      MISSING+=("Attack on (need at least 2, found $ATTACK_COUNT)")
    fi
    # Check that blockquotes exist (at least 2, one per attack target)
    QUOTE_COUNT=$(grep -c "^>" "$FILE")
    if [ "$QUOTE_COUNT" -lt 2 ]; then
      MISSING+=("Blockquote citations (need at least 2, found $QUOTE_COUNT)")
    fi
    # Frontmatter: check attacks array has severity fields
    SEVERITY_FM_COUNT=$(sed -n '/^---$/,/^---$/p' "$FILE" | grep -c "severity:")
    if [ "$SEVERITY_FM_COUNT" -lt 2 ]; then
      # Fallback: check body for severity mentions (any language/format)
      SEVERITY_BODY_COUNT=$(grep -c -i "severity\|嚴重性\|嚴重度" "$FILE")
      if [ "$SEVERITY_BODY_COUNT" -lt 2 ]; then
        MISSING+=("Severity ratings (need at least 2 in frontmatter or body, found fm:${SEVERITY_FM_COUNT} body:${SEVERITY_BODY_COUNT})")
      fi
    fi
    # Check that at least one high severity attack exists (frontmatter or body)
    HAS_HIGH=$(sed -n '/^---$/,/^---$/p' "$FILE" | grep -c "severity:.*high")
    if [ "$HAS_HIGH" -eq 0 ]; then
      if ! grep -qi "high" "$FILE"; then
        echo "WARNING: No high-severity attack found in $FILE (expected at least one)" >&2
      fi
    fi
    ;;
  3)
    check_section "Prior Position"
    check_section "Current Position"
    check_section "Changed"
    check_section "Attacks Survived"
    check_section "Attacks Not Answered"
    # Frontmatter validation
    check_frontmatter_field "position_changed" "yes|no"
    check_frontmatter_field "prior_position" "accept|reject|revise|investigate"
    check_frontmatter_field "current_position" "accept|reject|revise|investigate"
    ;;
  4)
    check_section "Ruling"
    check_section "Rationale"
    check_section "Winning Case"
    check_section "Minority Report"
    check_section "Unresolved Questions"
    check_section "Consensus Type"
    check_section "Next Actions"
    # Frontmatter validation
    check_frontmatter_field "ruling" "accept|reject|revise|investigate"
    check_frontmatter_field "consensus_type" "strong|weak|provisional"
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
