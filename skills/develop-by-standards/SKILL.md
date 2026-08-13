---
name: develop-by-standards
description: >-
  Apply MediaForge's mandatory development gates before, during, and after any
  change to source code, tests, configuration, scripts, documentation, plans,
  or agent tooling. Use for every artifact-changing task, including features,
  fixes, refactors, reviews with edits, and harness maintenance.
---

# Develop by Standards

Treat this workflow as a required acceptance gate, not as optional guidance.

## Workflow

1. Read `AGENTS.md` and
   `docs/standards/development-workflow.md` completely.
2. Read every standard applicable to the planned files. For Rust, QML, or
   CXX-Qt, always include `docs/standards/architecture.md` and
   `docs/standards/comment-content-rule.md`.
3. Inspect the current implementation, tests, manifests, and git status before
   editing. Preserve unrelated work.
4. Create or update `docs/plans/manuscripts/YYYYMMDD-<short-topic>.md` before
   implementation.
5. Implement the smallest coherent change while treating the standards as
   acceptance criteria. Keep tests, API documentation, semantic comments, and
   the manuscript synchronized with the design.
6. Run the automated verification required by the workflow standard. Fix every
   in-scope failure; do not bypass a check.
7. Inspect the final diff and complete every applicable item in the semantic
   audit from `docs/standards/development-workflow.md`.
8. Report the exact verification evidence and every skipped check, deviation,
   residual risk, or external prerequisite.

Stop and report a blocker when compliance needs a missing tool, user decision,
or authority. Never claim completion with an undisclosed failed gate.
