# Development Workflow Standard

This standard turns the repository's architecture, language, documentation,
and comment rules into mandatory acceptance gates. It applies to every agent or
human change to source code, tests, configuration, scripts, documentation,
plans, and development tooling.

## Enforcement model

Compliance has two complementary parts:

1. **Automated verification** checks deterministic properties such as
   formatting, types, lints, tests, and build success.
2. **Semantic audit** checks properties that tools cannot reliably decide, such
   as dependency direction, domain ownership, useful API contracts, and whether
   a non-obvious invariant needs a comment.

Passing automation does not imply semantic compliance. A change is complete
only when both parts pass. Never reduce a rule to a superficial metric: comment
counts, test counts, and coverage percentages cannot prove that the rule's
intent was met.

## Gate 1: preflight before editing

Before changing any artifact:

1. Read `AGENTS.md` and this document completely.
2. Read every standard applicable to the files or behavior in scope. Rust,
   QML, and CXX-Qt changes also require `architecture.md` and
   `comment-content-rule.md`.
3. Inspect the relevant implementation, tests, manifests, and repository status
   before choosing an approach. Treat existing violations as debt, not as
   precedent.
4. Create or update the relevant manuscript under `docs/plans/manuscripts/`
   before implementation. Record the goal, scope, constraints, and verification
   plan at a level proportional to the change.
5. State any requested behavior that conflicts with a repository standard. Do
   not silently choose one over the other.

Reading a summary, an earlier chat message, or a similarly named rule is not a
substitute for reading the current repository file.

## Gate 2: implementation discipline

While implementing:

- Keep dependencies pointing inward according to `architecture.md`. Identify
  the domain owner of every new boundary type and keep framework values at the
  edge.
- Make invalid states unrepresentable where practical. Validate untrusted data
  at boundaries and preserve structured failure information.
- Add or update tests for observable behavior, invariants, errors, cancellation,
  and boundary conversions affected by the change.
- Document every public API as required by its language standard. Documentation
  must state useful behavior, constraints, failures, side effects, or invariants
  instead of paraphrasing the symbol name or type.
- Review each changed algorithm, state transition, concurrency boundary,
  resource-lifetime boundary, external workaround, and recovery path against
  `comment-content-rule.md`. Add a semantic implementation comment when code,
  types, names, or tests cannot preserve the needed intent or warning.
- Refactor instead of commenting when a better name, type, function boundary,
  or test can express the information reliably.
- Keep the manuscript synchronized when implementation changes a material
  decision or uncovers a new constraint.

## Gate 3: automated verification

Run checks from the repository root. For source, test, build, dependency, or
configuration changes, run the repository verification entry point and
whitespace validation:

```text
bash scripts/verify.sh
git diff --check
```

`scripts/verify.sh` must include every active language and delivery gate. The
Qt shell requires `qmllint`, a non-mutating `qmlformat` comparison, QML tests,
a Qt application build, Cargo format, Clippy for all workspace targets and
features with warnings denied, Rust tests, and the macOS package verifier.
After an obsolete shell is removed, remove its gates rather than keeping an
unused toolchain as a verification dependency.

For documentation-only or agent-instruction-only changes, verify formatting,
all introduced local links, skill metadata when applicable, and
`git diff --check`. Run the full suite whenever a change can affect executable
behavior or tool configuration.

If a required tool or dependency is unavailable, stop and report the exact
command, failure, and installation requirement. Do not report the change as
verified. Never suppress, bypass, or weaken a check merely to make it pass.

## Gate 4: semantic audit before handoff

Inspect the final diff file by file and answer all applicable questions:

### Architecture and boundaries

- Do dependencies point inward, with concrete adapters selected only at a
  composition root?
- Are boundary values owned by the inner layer rather than by a framework or
  driver?
- Are side effects, runtime details, and external types kept outside the domain?

### Rust

- Are public items and non-obvious contracts documented with useful rustdoc?
- Are fallible runtime paths represented by `Result` or `Option` without
  unjustified panic, `unwrap`, or `expect`?
- Are cancellation, resource lifetime, shared state, and lock-order assumptions
  explicit and testable?
- Does every `unsafe` block have an immediately preceding `// SAFETY:` argument?

### QML and CXX-Qt

- Does presentation logic remain in QML while application and media policy stay
  in inward Rust crates?
- Are worker results queued to the Qt UI thread before QObject mutation or
  signal emission?
- Are custom controls keyboard accessible, named for assistive technology, and
  based on integer-millisecond media state?
- Does the bridge expose stable application values rather than framework types
  owned by inner layers?

### Comments and tests

- For every non-obvious decision, invariant, constraint, risk, side effect,
  domain mapping, and operational concern, is the information preserved in the
  best available form?
- Does each implementation comment fit exactly one allowed semantic category
  and prevent a concrete future mistake?
- Were narrative, decorative, stale, or code-restating comments removed?
- Do tests cover the changed behavior and meaningful failure paths without
  coupling to private implementation steps?

### Scope and integrity

- Does the diff contain only authorized, relevant changes and preserve unrelated
  user work?
- Are secrets, generated artifacts, local machine paths, and temporary files
  excluded?
- Does the implementation still match the manuscript and the user's acceptance
  criteria?

Any failed answer is unresolved work unless the user explicitly accepts a
documented deviation.

## Gate 5: handoff evidence

The final report must state:

- what changed;
- which automated commands ran and whether each passed;
- that the final semantic audit was completed;
- any skipped check, known deviation, residual risk, or required external
  verification.

Do not use phrases such as "fully compliant", "complete", or "all checks pass"
without the corresponding evidence from the current working tree.
