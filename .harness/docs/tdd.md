# TDD — Test-Driven Development contract

> Owner: `swiftwebui-tester`. Architects and PR reviewers enforce.

## Why this exists

SwiftWebUI is a public framework. Every public type ships with a
test that proves the contract. The TDD discipline is the project's
insurance against breaking the public surface.

## Test frameworks

- **swift-testing** (`@Test`, `@Suite`, `#expect`, `#require`) is the
  test framework of record.
- Snapshot tests (DOM tree comparison) live in
  `Tests/SwiftWebUISnapshots/`.
- WebDriver / Playwright smoke tests live in
  `Tests/SwiftWebUIWebDriver/`.

## The TDD rule

> No production code lands in `main` without a failing test in the
> same (or earlier) commit.

Specifically:

1. **Red**: open a PR with a failing test that describes the new
   behaviour. The CI matrix must show red on the relevant test
   target.
2. **Green**: commit the smallest implementation that makes the test
   pass. CI goes green.
3. **Refactor**: clean up while keeping tests green.

The PR description for any non-trivial change must show
`red commit hash → green commit hash` for the test pair.

## Test categories

### Unit tests (`Tests/SwiftWebUITests/`)

- Pure-Swift, no JavaScriptKit.
- Covers: View protocol conformance, ViewBuilder result-builder
  semantics, `EnvironmentValues` key resolution, modifier chain
  identity, type erasure (`AnyView`).
- Runs on the native (host) Swift target — fast feedback.

### Snapshot tests (`Tests/SwiftWebUISnapshots/`)

- Renders a View to the **graph** (not the live DOM) using a fake
  renderer, then asserts the graph matches a checked-in snapshot.
- The snapshot files are **committed to git** (no auto-update on
  CI). A change to a snapshot is a deliberate PR.
- Examples: `Text("hi")` → graph of `[.text("hi")]`,
  `VStack { Text("a"); Text("b") }` → graph of
  `[.vstack { .text("a"); .text("b") }]`.

### WebDriver / Playwright smoke (`Tests/SwiftWebUIWebDriver/`)

- Builds the wasm32 target, hosts it, opens it in a real browser
  via Playwright, and asserts the rendered DOM matches a snapshot.
- Slow, runs on CI only (and a manual `./scripts/serve.sh` locally).
- Backing for: the first `Text("hi")` actually shows `<div>hi</div>`
  in a real browser. This is the `swiftwebui-dom-renderer`
  stop-condition test.

## CI matrix

CI must run, per push to a PR:

- [ ] `swift build` on the host target.
- [ ] `swift test` on the host target (unit + snapshot).
- [ ] `swift build --triple wasm32-unknown-wasi`.
- [ ] WebDriver smoke (only on `main` and on release tags — PR
      branches may skip the slow path if the snapshot tests are
      green).
- [ ] `swift package generate-documentation` — must complete with
      zero warnings.

The `swiftwebui-tester` agent owns the matrix file and the GitHub
Actions workflow YAML. The `swiftwebui-steward` agent owns the
workflow's *placement* (it's an OSS concern), but the YAML body is
tester's.

## Red flags the tester agent must raise

- A PR's commit history shows the implementation landing **before**
  the test for non-trivial logic. Tester requests a rebase.
- A snapshot file was changed without a "WHY" line in the PR
  description.
- A new public symbol has no DocC comment + no test.
- A new modifier is missing a View-extension signature and a test.
- A test name says "TODO" or is empty.

## What is not a TDD violation

- Mechanical changes: reformatting, import sorting, file moves.
- Locked-decision documentation updates (no code change).
- SPI surface under `@_spi(Experimental)` MAY have tests land
  concurrently (still encouraged to be red-first, but the
  enforcement is soft until the SPI graduates to public).
