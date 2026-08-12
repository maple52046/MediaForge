# Codex Harness Integration

## 1. Purpose

Provide Codex-native discovery for MediaForge's repository instructions and
reusable agent skills while preserving the existing Cursor integration and a
single canonical definition for each workflow.

## 2. Source Scope

This plan consolidates one manuscript:

- `docs/plans/manuscripts/20260812-codex-harness.md`

The source records the confirmed Codex mechanisms, implementation boundaries,
completed integration work, and validation results.

## 3. Consolidated Background

MediaForge already stores repository-wide development guidance in `AGENTS.md`,
canonical reusable workflows in `skills/`, and Cursor-specific discovery
wrappers in `.cursor/skills/`. Codex uses different discovery locations:
repository guidance comes from `AGENTS.md`, while repository skills are scanned
from `.agents/skills/` between the working directory and Git root.

Project-local `.codex/` files serve a different purpose. They configure trusted
project settings, hooks, MCP integration, sandbox behavior, and command
execution policies; they are not the Codex counterpart of Cursor coding-style
`.mdc` rules.

## 4. Confirmed Decisions

- Keep `skills/<name>/SKILL.md` as the canonical workflow definition.
- Use `.agents/skills/<name>/SKILL.md` only as a thin Codex discovery wrapper.
- Continue using `.cursor/skills/<name>/SKILL.md` as the Cursor wrapper.
- Let Codex consume the root `AGENTS.md` directly for repository instructions.
- Document both integrations in `AGENTS.md` and `skills/README.md`.
- Do not create `.codex/skills/` or speculative `.codex` configuration.

## 5. Architecture and Design Principles

The integration follows a single-source-of-truth design. Agent-specific entry
points contain discovery metadata and a relative link to the canonical skill;
they do not duplicate the workflow. This prevents Cursor and Codex behavior
from drifting while keeping each agent's native discovery convention.

Repository guidance remains layered separately from reusable workflows:
`AGENTS.md` establishes always-applicable project constraints, and skills load
task-specific instructions only when invoked or matched.

## 6. Functional Scope

The Codex integration exposes these existing repository skills:

- `git-commit`
- `summarize-manuscript-plans`

Codex may activate them explicitly through `$<name>` or implicitly by matching
their descriptions. The integration also makes the relationship between
canonical skills, Codex wrappers, and Cursor wrappers discoverable to future
contributors.

## 7. Constraints and Rules

- Every wrapper must contain valid `name` and `description` frontmatter.
- Wrapper links must resolve to an existing canonical `SKILL.md`.
- Wrappers must remain thin and must not fork canonical instructions.
- Existing Cursor wrappers must remain unchanged unless a Cursor-specific task
  requires a change.
- Project source code is outside the scope of harness integration.
- Do not add model selection, sandbox permissions, MCP servers, hooks, or
  command policies without a concrete project requirement.

## 8. Data Model and Format Notes

Each repository skill uses this layout:

```text
skills/<name>/SKILL.md                 # Canonical workflow
.agents/skills/<name>/SKILL.md         # Codex discovery wrapper
.cursor/skills/<name>/SKILL.md         # Cursor discovery wrapper
```

The Codex wrapper uses YAML frontmatter with the canonical skill name and a
concise trigger description, followed by instructions to read and follow the
canonical relative path.

## 9. CLI / API / Config Notes

- Codex CLI and the IDE extension discover repository skills from
  `.agents/skills/`.
- Users can list skills with `/skills` and explicitly invoke a skill with
  `$<name>`.
- Codex discovers `AGENTS.md` from the repository root toward the current
  working directory.
- `.codex/config.toml` and `.codex/rules/*.rules` are unnecessary for the
  current instruction and skill discovery requirements.
- The implementation was checked with the installed Codex CLI's
  `debug prompt-input` diagnostic.

## 10. Implementation Plan

1. Add thin Codex wrappers for `git-commit` and
   `summarize-manuscript-plans` under `.agents/skills/`.
2. Update `AGENTS.md` to explain that Codex consumes it directly and discovers
   repository skills from `.agents/skills/`.
3. Update `skills/README.md` with Codex and Cursor wrapper conventions.
4. Verify wrapper frontmatter and canonical relative links.
5. Confirm through Codex CLI diagnostics that the root instructions and both
   repository skills appear in model-visible input.
6. Run whitespace and repository-status checks.

All six steps have been completed successfully.

## 11. Non-goals

- Duplicating Cursor `.mdc` rules for Codex.
- Adding a `.codex/skills/` directory.
- Configuring models, providers, permissions, sandbox behavior, MCP, hooks, or
  command allow/deny policies.
- Changing canonical workflow behavior or project application source code.
- Packaging the skills as distributable plugins.

## 12. Open Questions

There are no unresolved questions for the current integration. Future
requirements for project-local `.codex` configuration should be evaluated only
when a concrete setting, hook, MCP server, or command policy is needed.

## 13. Future Work

- Add a matching `.agents/skills/<name>/SKILL.md` wrapper whenever a new
  canonical repository skill is introduced.
- Validate new wrappers with Codex diagnostics and relative-link checks.
- Introduce project-local `.codex` configuration only in response to an
  explicit operational or security requirement.
