# AGENTS.md

Guidance for AI agents (and human contributors) working in this repository.
This project uses **Rust as its primary implementation language** and
**TypeScript as a secondary implementation language**.

## Mandatory development workflow

Any task that creates or modifies repository artifacts MUST follow
[`skills/develop-by-standards/SKILL.md`](skills/develop-by-standards/SKILL.md),
even when the agent does not automatically select that skill. This requirement
applies to source code, tests, configuration, scripts, documentation, plans,
and agent tooling.

The workflow is fail-closed: before editing, read the applicable standards and
create or update the relevant plan manuscript; before handoff, run the required
automated checks and complete the semantic audit. Do not claim completion while
a required check is failing or a known deviation is undisclosed.

## Development standards

If you are going to write or modify code (or other project artifacts), you MUST
read and follow these project standards first:

- **Development workflow** -
  [`docs/standards/development-workflow.md`](docs/standards/development-workflow.md):
  the mandatory preflight, implementation, verification, semantic audit, and
  handoff gates for every repository change.

- **Architecture** - [`docs/standards/architecture.md`](docs/standards/architecture.md):
  the Clean Architecture dependency rule. Dependencies point inward only; the
  domain never depends on adapters, concrete drivers, or frameworks; data
  crossing boundaries is a domain-owned type; cross-layer work goes through
  abstractions (ports) implemented in outer layers and wired at the composition
  root.
- **Rust style (primary)** - [`docs/standards/rust-style.md`](docs/standards/rust-style.md):
  use idiomatic stable Rust, let `rustfmt` own formatting, treat Clippy warnings
  as errors, model fallibility with `Result`, document public APIs with rustdoc,
  and justify every `unsafe` block with a `// SAFETY:` comment.
- **TypeScript style (secondary)** - [`docs/standards/typescript-style.md`](docs/standards/typescript-style.md):
  keep strict types and named exports, prefer simple interfaces and `unknown`
  over `any`, use TypeScript's standard module system, and enforce the codebase
  with the compiler, ESLint, and Prettier.
- **Comment content** - [`docs/standards/comment-content-rule.md`](docs/standards/comment-content-rule.md):
  a comment must belong to exactly one semantic category (Intent / Rationale /
  Contract / Invariant / Constraint / Risk / Side Effect / Domain Mapping /
  Operational Context) and must not restate code, translate names, or narrate
  control flow. Conversely, *do* add a comment wherever a non-obvious decision,
  constraint, invariant, or risk needs to be recorded so it is not lost. API
  documentation comments are always expected where the style standard requires
  them.

Read each applicable standard completely before editing, and keep it open as a
binding acceptance criterion throughout the task. Existing non-compliant code
is not precedent for new work.

## Additional standards (read when relevant)

- **Commit messages** - [`docs/standards/conventional-commits.md`](docs/standards/conventional-commits.md):
  Conventional Commits 1.0.0. Commit messages MUST be written in English.

## Project plans

Save project plan manuscripts under `docs/plans/manuscripts/` as
`YYYYMMDD-<short-topic>.md` (see
[`docs/plans/manuscripts/README.md`](docs/plans/manuscripts/README.md)). Create
or update the relevant plan file before implementing.

### Historical plans — do not read by default

`docs/plans/` holds historical, consolidated plans kept only for long-term
reference. Reading them wastes context/tokens and is almost never needed for
development.

- You MUST NOT open, read, search (grep), or glob any file directly under
  `docs/plans/` unless the user's task explicitly asks you to consult a specific
  historical plan.
- This does NOT block the normal plan workflow: you may still create or update
  drafts under `docs/plans/manuscripts/`, and read
  `docs/plans/manuscripts/README.md` when running the plan-consolidation skill.

## Skills

Task-specific operating guides live under `skills/` (see
[`skills/README.md`](skills/README.md) for the index). Read a skill only when
the current task matches its purpose. Codex discovers repository skill entry
points under `.agents/skills/` and consumes this `AGENTS.md` directly. Cursor
exposes the same canonical skills as `/`-commands via thin wrappers under
`.cursor/skills/`. The mandatory development workflow above is the exception to
task-specific selection: use it for every artifact-changing task.
