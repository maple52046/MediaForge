# Architecture Standard

This project follows **The Clean Architecture** (Robert C. Martin). This
document adapts its single load-bearing rule — *The Dependency Rule* — to a
Rust and TypeScript codebase. Rust is the primary implementation language;
TypeScript is secondary. The standard is self-contained so the project can be
used and open-sourced independently.

> Source of the underlying principles: Robert C. Martin, *The Clean
> Architecture*, 2012. <https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html>

## The Dependency Rule

Source-code dependencies point **inwards only**. An inner layer must never name
anything declared in an outer layer (no function, type, constant, or data
format defined further out). Data crossing a boundary is a plain structure
owned by the inner layer — never a framework-shaped or driver-shaped value.

In Rust, enforce the rule at crate and module boundaries: core crates expose
domain types and port traits but never depend on adapter crates, async runtimes,
or framework types. In TypeScript, inner packages import only other inner
packages and define their own boundary interfaces; framework request objects,
ORM records, and browser or Node.js APIs remain outside the core. Shared types
belong to the innermost layer that owns their meaning, not to a generic adapter
package.

## Layers (inner to outer)

1. **Domain (innermost).** The core types of the system and the contracts that
   describe its behaviour. Pure data and abstractions: no I/O, no concurrency
   runtime, no clock, no filesystem, no third-party framework beyond a minimal
   data-modelling/serialization dependency.
2. **Use cases.** Application policy: orchestrate the domain types to fulfil a
   request. Depends only on the domain layer and on the **abstract ports**
   below — never on a concrete adapter.
3. **Interface adapters.** Convert between the domain form and the outside
   world: parsers/serializers, persistence backends, the CLI/HTTP surface.
   They depend inwards on the domain/use-case layers and implement the ports.
4. **Frameworks & drivers (outermost).** Concrete details: the runtime, the
   system clock, the filesystem, databases, network clients, third-party
   libraries. Mostly glue wired together at the composition root.

## Ports (cross dependencies via inversion)

When an inner layer must trigger work that lives further out (persist data, read
a clock, call a service), it depends on an **abstract port** — an abstraction
defined inward — and the outer layer provides the implementation. The use-case
layer references only these abstractions, so adding a new backend, a new
transport, or a new driver never edits the core.

Rust ports are small traits defined by the consuming domain or use-case crate.
Inject implementations through generic parameters when static dispatch helps,
or through `dyn Trait` at runtime boundaries; choose concrete adapters only at
the composition root. TypeScript ports are narrow `interface`s owned by the
consumer package and passed explicitly to use cases, commonly through
constructors or factory functions. Do not use a service locator or import a
concrete implementation from an inner package.

## Project rules derived from the above

- The domain MUST NOT depend on adapters, drivers, frameworks, or a concurrency
  runtime.
- A concrete adapter depends on the core's abstractions; the core never names a
  specific adapter. Adapters are selected at the composition root.
- Drivers sit behind ports. Swapping one driver for another is a new
  implementation of an existing abstraction, not a change to the domain or use
  cases.
- Data crossing boundaries is a domain-owned type, never a driver-specific
  structure or a raw record leaking outward.
- Side-effecting details (which database, which transport, which time source)
  are *details* and live at the edges.
- A Rust/TypeScript boundary serializes through an explicitly versioned contract
  owned by the application, not through either side's internal representation.

## Recommended layout

Keep deployable applications and reusable layers visibly separate. A suitable
starting layout is:

```text
crates/
  domain/          # Rust entities, value objects, and inward-owned port traits
  application/     # Rust use cases
  adapters/        # Rust implementations of ports and boundary conversion
apps/              # Rust binaries and composition roots
packages/
  domain/          # TypeScript domain types and inward-owned interfaces
  application/     # TypeScript use cases
  adapters/        # TypeScript framework and driver adapters
  app/             # TypeScript entry point and composition root
```

This is a direction, not a requirement to create empty packages. Smaller
features may use modules inside one crate or package while preserving the same
dependency direction. Cross-language contract definitions should have one
clear owner and generated artifacts, if any, must stay outside the domain.

## Testability consequence

Because policy does not depend on details, use cases and domain logic are
unit-testable without a runtime, without a real clock, and without touching the
filesystem or network — test doubles implement the ports. This is the property
the architecture exists to guarantee.
