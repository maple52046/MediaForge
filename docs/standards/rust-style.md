# Rust Style Standard

Rust is the primary implementation language of this project. This standard
distills the official Rust Style Guide, Rust API Guidelines, Google
Comprehensive Rust guidance, and the Rust for Linux coding guidelines, keeping
the rules that drive day-to-day judgment. It is self-contained for open-source
use.

> Sources: <https://doc.rust-lang.org/1/style-guide/>,
> <https://rust-lang.github.io/api-guidelines/>, and
> <https://android.googlesource.com/kernel/common/+/refs/tags/android14-6.1-2025-05_r7/Documentation/rust/coding-guidelines.rst>.
> Formatting is enforced by `rustfmt`; lints by Clippy. This document covers
> the judgment calls those tools cannot make.

## Baseline

- Use stable Rust and the edition declared by the workspace `Cargo.toml` once
  the build manifest is initialized. Nightly-only features require an explicit,
  documented project decision.
- **Format with `rustfmt`** using its default style; never hand-format around it.
- **Lint with Clippy**; treat warnings as errors in CI.
- Run `cargo fmt --check`,
  `cargo clippy --all-targets --all-features -- -D warnings`, and `cargo test`
  before committing once the Cargo workspace exists.

## Modules & imports

- Organize modules around domain capabilities, not framework or utility buckets.
- Keep the public module surface small. Prefer private items and deliberate
  `pub(crate)` visibility over exporting implementation details.
- Group imports as `std`, external crates, and local modules; let `rustfmt`
  decide layout. Avoid wildcard imports outside tightly scoped preludes or tests.
- Inner crates must not import adapters, drivers, runtimes, or framework crates;
  follow [`architecture.md`](architecture.md).

## Types & data modelling

- Use structs and enums to make domain states explicit. Prefer an enum over
  combinations of booleans or magic strings.
- Introduce newtypes when values share a representation but not a meaning or
  invariant. Validate at construction so invalid states cannot flow inward.
- Accept borrowed inputs when ownership is unnecessary; return owned values
  when ownership transfer is part of the API contract. Do not clone merely to
  silence borrow-checker errors without understanding the ownership boundary.
- Define cross-layer data in the inner layer that owns its meaning. Do not leak
  database rows, HTTP types, or serialization-library values into the domain.

## Error handling

- Represent expected failure with `Result<T, E>` and absence with `Option<T>`.
  Do not use panics for normal runtime errors.
- Library and domain boundaries expose specific, inspectable error types;
  `thiserror` is appropriate for their implementations. Binary composition
  roots may use `anyhow` to attach operational context without weakening inner
  contracts.
- Do not call `unwrap` or `expect` on fallible runtime input. They are acceptable
  only where an invariant makes failure impossible and that invariant is clear
  from the type, test setup, or a concise rationale.
- Add context at boundaries while preserving the original source error. Never
  silently discard an error.

## Naming

- Follow Rust API naming: `UpperCamelCase` for types and traits,
  `snake_case` for modules, functions, methods, and variables, and
  `SCREAMING_SNAKE_CASE` for constants and statics.
- Use precise domain names rather than placeholders such as `Foo`, `Bar`, or
  vague `Manager` and `Util` types. Do not repeat module or type context in item
  names.
- Name conversions consistently: `as_` for cheap borrowed conversions, `to_`
  for potentially allocating conversions, and `into_` for ownership-consuming
  conversions.

## Documentation

- Write rustdoc (`///` or `//!`) for every public item and for non-obvious
  internal contracts. The first paragraph is one sentence summarizing the item.
- Link Rust items with intra-doc links. Add `# Errors`, `# Panics`, `# Safety`,
  and `# Examples` sections when those contracts apply.
- Every `unsafe fn` or unsafe trait documents the caller's or implementor's
  obligations under `# Safety`.
- Documentation explains the API contract and domain meaning; implementation
  comments explain local decisions. Do not substitute one for the other.

## Comments

Comments explain **intent**, not mechanics. Never narrate what the code does.
The full content rule is binding: see
[`comment-content-rule.md`](comment-content-rule.md).

`TODO` format: `// TODO(owner-or-issue): Concrete follow-up and its constraint.`

Every `unsafe` block must be immediately preceded by a `// SAFETY:` comment
that states why all relevant safety preconditions hold. This comment is
required even when the reasoning appears obvious.

## Functions, state & structure

- Keep functions focused on one level of abstraction. Extract parsing,
  conversion, and side effects from domain decisions.
- Prefer immutable bindings. Use mutation when it makes ownership and state
  transitions clearer, and keep the mutable scope narrow.
- Prefer iterators when they express a transformation clearly; use explicit
  loops when control flow or error handling is easier to read that way.
- Keep trait contracts small and consumer-owned. Avoid speculative abstraction
  and generic parameters that do not enforce a real invariant.

## Concurrency

- Keep the domain independent of Tokio or any other runtime. Put task spawning,
  timers, channels, and cancellation mechanics in outer layers behind ports.
- Prefer message passing or explicit ownership over shared mutable state. When
  shared state is necessary, document lock ordering and keep guards out of
  `.await` points.
- Propagate cancellation and task errors deliberately; do not detach work whose
  lifetime and failure semantics matter to the caller.

## Testing

- Put focused unit tests beside the code in `#[cfg(test)] mod tests`; put
  cross-crate or public-contract tests under `tests/`.
- Test observable behavior and domain invariants, including error paths and
  boundary conversions. Avoid asserting private implementation steps.
- Use test doubles that implement ports; domain and use-case tests must not need
  the network, filesystem, wall clock, database, or async runtime unless that
  mechanism is the subject of the test.

## Parting rule

**Be consistent** with surrounding code; let consistency converge toward this
standard over time rather than freezing an older local style.
