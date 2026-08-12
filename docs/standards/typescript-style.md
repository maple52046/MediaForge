# TypeScript Style Standard

TypeScript is the secondary implementation language of this project. This
standard distills the Google TypeScript Style Guide, keeping the rules that
drive day-to-day judgment. It is self-contained for open-source use.

> Source: <https://google.github.io/styleguide/tsguide.html>. Formatting is
> enforced by Prettier; lints by ESLint and the TypeScript compiler. This
> document covers the judgment calls those tools cannot make.

## Baseline

- Use the TypeScript version and ECMAScript target pinned by the project once
  `package.json` and `tsconfig.json` are initialized. Enable strict type
  checking; weakening an individual strictness rule requires a documented
  project decision.
- **Format with Prettier**; never hand-format around it.
- **Lint with ESLint and type-check with `tsc --noEmit`**; treat warnings as
  errors in CI.
- Run `tsc --noEmit`, `eslint .`, `prettier --check .`, and the configured test
  runner before committing once the TypeScript toolchain exists.

## Modules & imports

- Use ES modules and named exports. Do not use default exports, TypeScript
  namespaces, `/// <reference>`, or `import x = require(...)`.
- Use `import type` and `export type` for symbols used only as types. Prefer
  relative imports inside a package and avoid deep parent traversal.
- Export only symbols used outside the module; never export mutable bindings.
  Use a function when external code needs controlled access to changing state.
- Keep file order predictable: optional copyright/file overview, imports, then
  implementation, with one blank line between sections.

## Types & data modelling

- Prefer interfaces for object-shaped contracts and discriminated unions for
  finite state. Use the simplest type that expresses the invariant; avoid
  clever mapped or conditional types when explicit declarations are clearer.
- Prefer `unknown` over `any` and narrow it at the boundary. Avoid `{}` and the
  wrapper types `String`, `Boolean`, `Number`, and `Object`.
- Prefer `T[]` or `readonly T[]` for simple element types and `Array<T>` for
  complex element types. Use `Map`, `Set`, or `Record` when they match the
  domain more closely than an index signature.
- Add `null` or `undefined` at the use site rather than hiding it in a type
  alias. Prefer optional fields and parameters to explicit `| undefined`.
- Explicitly annotate structural implementations at their declaration so type
  failures appear at the implementation boundary.

## Error handling

- Throw only `Error` instances or subclasses, and use custom error classes when
  callers need to distinguish failure categories. Use discriminated result
  unions when failure is an expected domain outcome rather than an exception.
- Catch values as `unknown`, narrow before access, and never leave an empty
  catch block without a concrete rationale. Keep `try` blocks focused on the
  operations that can throw.
- Avoid non-null and type assertions. When an external invariant makes one
  unavoidable, validate when possible and document the reason at the assertion.
- Do not suppress compiler errors with `@ts-ignore`, `@ts-expect-error`, or
  `@ts-nocheck`; fix the type boundary instead. A narrowly scoped test exception
  requires a documented reason.

## Naming

- Use `UpperCamelCase` for classes, interfaces, types, enums, decorators, and
  type parameters; `lowerCamelCase` for variables, parameters, functions,
  methods, properties, and module aliases; `CONSTANT_CASE` for true module-level
  constants and enum values.
- Use `snake_case` file names. Treat acronyms as words (`loadHttpUrl`,
  `customerId`) and do not prefix or suffix identifiers with underscores.
- Choose descriptive domain names. Do not encode information already present in
  the type, shorten words ambiguously, or use container classes as namespaces.

## Documentation

- Document every top-level export and non-obvious public contract with Markdown
  JSDoc/TSDoc. Rely on TypeScript types instead of repeating them in `@param` or
  `@return` tags.
- State behavior, invariants, side effects, and failure conditions. Do not merely
  restate the symbol name or type.
- Put JSDoc before decorators. Mark deprecated APIs with `@deprecated` and give
  callers a concrete migration path.

## Comments

Comments explain **intent**, not mechanics. Never narrate what the code does.
The full content rule is binding: see
[`comment-content-rule.md`](comment-content-rule.md).

`TODO` format: `// TODO(owner-or-issue): Concrete follow-up and its constraint.`

Use `/** ... */` for API documentation and `//` lines for implementation
comments. Do not draw decorative block-comment boxes.

## Functions, state & structure

- Default to `const`; use `let` only for reassignment and never use `var`.
  Declare one variable per statement.
- Prefer function declarations for named functions and arrow functions for
  callbacks. Use a block-bodied arrow when its return value is intentionally
  ignored. Explicitly forward callback parameters.
- Keep functions focused and prefer an options interface over a long list of
  optional or boolean parameters. Parameter default expressions must be simple
  and free of observable side effects.
- Mark never-reassigned class properties `readonly`, initialize fields where
  declared, and limit visibility. Prefer module-local functions over static
  utility methods.
- Always use braced control-flow blocks and `===`/`!==` except for a deliberate
  `value == null` check covering both nullish values.

## Concurrency

- Treat every promise as an owned operation: await or return it, and handle its
  rejection. Do not start untracked asynchronous work whose lifetime matters.
- Propagate cancellation across boundaries with an explicit contract such as an
  injected signal; adapters translate platform cancellation into that contract.
- Keep timers, workers, browser APIs, and Node.js runtime details outside the
  domain. Ports expose domain-level asynchronous results rather than framework
  request or response objects.
- Avoid shared mutable state across concurrent callbacks. When unavoidable,
  centralize mutation and make ordering assumptions explicit and testable.

## Testing

- Use `*.test.ts` or the test runner's established repository convention. Keep
  unit tests beside the behavior they specify or in a consistent test tree.
- Test public behavior, discriminated states, errors, and boundary conversion.
  Do not couple tests to private implementation order.
- Inject port implementations and deterministic clocks. Domain and use-case
  tests must not require a real network, filesystem, browser, database, or wall
  clock.

## Parting rule

**Be consistent** with surrounding code; let consistency converge toward this
standard over time rather than freezing an older local style.
