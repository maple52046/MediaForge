---
name: git-commit
description: >-
  Analyse the repository's changes, write a high-quality Conventional Commits
  message, and run git commit, optionally staging or pushing when explicitly
  requested. Use when the user invokes $git-commit or asks Codex to commit
  changes with a generated message.
---

# Git Commit — Codex Entry

This is the Codex discovery entry point. The canonical instructions live in
[`skills/git-commit/SKILL.md`](../../../skills/git-commit/SKILL.md), relative to
the repository root.

Read the canonical file completely and follow it exactly. Keep this wrapper
thin so the workflow has one source of truth.

Invocation:

```text
$git-commit [--auto-add] [--all] [--push] [--date <when>]
```
