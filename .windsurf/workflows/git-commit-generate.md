---
description: Generate appropriate git commit messages for staged files following project conventions.
---

**Guardrails**
- Do NOT execute `git commit` - only propose messages and leave the actual commit to the user.
- Respect existing project patterns and maintain consistency.
- For complex changes, summarize appropriately while not missing important information.
- Ask for clarification if anything is unclear.

**Steps**
1. Check project commit rules by reading `CLAUDE.md`, `README.md`, or any documentation that defines commit message conventions. If found, follow those rules as top priority.
2. Run `git diff --cached` to analyze staged files and identify the nature of changes (new features, bug fixes, refactoring, documentation updates, etc.).
3. Run `git log --oneline -10` to analyze recent commit message formats. Pay attention to:
   - Language used (English, Chinese, etc.)
   - Message structure (single-line vs multi-line)
   - Prefix usage (feat:, fix:, docs:, etc.)
   - Writing style and tone patterns
4. Generate a commit message that matches project conventions, accurately describes changes, and is easily understood by future developers.
5. Present the proposed commit message and instruct: "Please run `git commit -m '<message>'` yourself."

**Error Handling**
- If no files are staged, report: "No staged files found. Please stage your changes with `git add` first."
- If not in a git repository, report: "This directory is not a git repository."
- If project conventions can't be determined, follow conventional commits format and explain this to the user.
