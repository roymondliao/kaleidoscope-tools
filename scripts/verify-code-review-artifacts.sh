#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

failures=0

require_file() {
  local file="$1"
  if [[ ! -f "$ROOT_DIR/$file" ]]; then
    printf 'FAIL missing file: %s\n' "$file"
    failures=$((failures + 1))
  fi
}

require_pattern() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! grep -Eq -- "$pattern" "$ROOT_DIR/$file"; then
    printf 'FAIL %s: %s\n' "$file" "$message"
    failures=$((failures + 1))
  fi
}

require_file "agents/code-reviewer.md"
require_file "skills/code-review/SKILL.md"
require_file "skills/code-review/reference/review-result-template.md"
require_file "skills/code-review/reference/comment-payload-template.md"
require_file "changes/2026-05-29_code-review-skill/evaluator.md"

require_pattern "README.md" '\| `code-review` \|' "README must list code-review skill"
require_pattern "README.md" '\| `code-reviewer` \|' "README must list code-reviewer agent"

require_pattern "agents/code-reviewer.md" 'Project Information' "subagent contract must require project information"
require_pattern "agents/code-reviewer.md" 'PR Information' "subagent contract must require PR information"
require_pattern "agents/code-reviewer.md" 'PR Intent' "subagent contract must require PR intent"
require_pattern "agents/code-reviewer.md" 'Assigned Review Unit' "subagent contract must require assigned review unit"
require_pattern "agents/code-reviewer.md" 'Test Scope Boundary' "subagent contract must require test scope boundary"
require_pattern "agents/code-reviewer.md" 'status: malformed_input' "subagent must define malformed input state"

require_pattern "skills/code-review/SKILL.md" 'git rev-parse HEAD' "skill must verify local HEAD"
require_pattern "skills/code-review/SKILL.md" 'headRefOid' "skill must compare against PR head SHA"
require_pattern "skills/code-review/SKILL.md" 'Checkout outcome unknown' "skill must stop on ambiguous checkout"
require_pattern "skills/code-review/SKILL.md" 'broad_tests_read: false' "skill must state broad tests reconnaissance boundary"
require_pattern "skills/code-review/SKILL.md" 'degraded_mode: true' "skill must expose degraded project reconnaissance"
require_pattern "skills/code-review/SKILL.md" 'Do not run `gh api` in dry-run mode' "skill must prohibit dry-run posting"
require_pattern "skills/code-review/SKILL.md" 'posting_executed: false' "skill must prove dry-run did not post"
require_pattern "skills/code-review/SKILL.md" 'Do not infer approval' "skill must require posting-specific approval"
require_pattern "skills/code-review/SKILL.md" 'https://github.com/\{owner\}/\{repo\}/pull/\{number\}' "skill must define PR URL parsing pattern"
require_pattern "skills/code-review/SKILL.md" 'If owner, repo, or pull number cannot be determined unambiguously' "skill must block ambiguous endpoint coordinates"
require_pattern "skills/code-review/SKILL.md" 'Do not inline markdown `body`' "skill must avoid shell-inlining untrusted comment body"
require_pattern "skills/code-review/SKILL.md" '--input <payload-json-file>' "skill must post from JSON input file"

for field in commit_id path line side body; do
  require_pattern "skills/code-review/reference/comment-payload-template.md" "$field" "payload template must include $field"
  require_pattern "changes/2026-05-29_code-review-skill/evaluator.md" "$field" "evaluator must require $field"
done

require_pattern "changes/2026-05-29_code-review-skill/evaluator.md" '/code-review https://github.com/OWNER/REPO/pull/123 --dry-run' "evaluator must use a placeholder closed PR fixture in dry-run mode"
require_pattern "changes/2026-05-29_code-review-skill/evaluator.md" 'posting_executed: false' "evaluator must require no posting"
require_pattern "changes/2026-05-29_code-review-skill/evaluator.md" 'Subagent Task Prompt Evidence' "evaluator must require subagent task prompt evidence"
require_pattern "changes/2026-05-29_code-review-skill/evaluator.md" 'gh api POST /repos/\{owner\}/\{repo\}/pulls/\{pull_number\}/comments' "evaluator must fail if posting command runs"
require_pattern "changes/2026-05-29_code-review-skill/fixture-verification.md" 'headRefOid: "<fixture-head-sha>"' "fixture verification template must record PR head SHA placeholder"
require_pattern "skills/code-review/reference/comment-payload-template.md" '--input <payload-json-file>' "payload template must avoid shell-inlining comment body"

if [[ "$failures" -gt 0 ]]; then
  printf '\ncode-review artifact verification failed: %d issue(s)\n' "$failures"
  exit 1
fi

printf 'code-review artifact verification passed\n'
