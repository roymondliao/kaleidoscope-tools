---
name: create-pr
description: Create a pull request with a standardized body template, auto-filled from git context with a review gate before submission. Use when the user wants to create a PR, open a pull request, or run /create-pr.
allowed-tools:
- Bash(git status:*)
- Bash(git branch:*)
- Bash(git checkout:*)
- Bash(git add:*)
- Bash(git commit:*)
- Bash(git push:*)
- Bash(git diff:*)
- Bash(git log:*)
- Bash(git rev-list:*)
- Bash(git remote:*)
- Bash(gh pr create:*)
- Bash(gh pr view:*)
- Bash(which gh:*)
- Read
- Grep
- Glob
user-invocable: true
argument-hint: (no arguments needed)
---

# Create PR

Create a pull request with a standardized body template. Auto-fills PR content from git context, asks for Jira ticket, presents a draft for user approval, then creates the PR.

## Prerequisites Check

Before starting the workflow, verify these conditions. If any fail, stop and report the issue to the user:

1. **Git repository**: Run `git rev-parse --is-inside-work-tree`. If it fails, stop: "This is not a git repository."
2. **Remote exists**: Run `git remote get-url origin`. If it fails, stop: "No remote named 'origin' configured."
3. **gh CLI installed**: Run `which gh`. If it fails, stop: "GitHub CLI (gh) is not installed. Install it from https://cli.github.com/"
