---
name: tester
description: Local rein for swiftwebui-tester inside swift-web-ui. Owns Tests/, TDD enforcement, snapshot and WebDriver smoke, CI matrix body. Import of the global swiftwebui-tester agent.
---

# tester (project rein)

This is a **project-side wrapper**. The canonical spec for this role
lives at `~/.mavis/agents/swiftwebui-tester/agent.md` (a global
Mavis agent). Read that file first; this file adds the
swift-web-ui project context only.

## Import statement

- **Global agent**: `swiftwebui-tester`
- **Local rein directory**: `.harness/reins/tester/`
- **Do not** redefine the global agent's system prompt here.

## Project context (swift-web-ui specific)

- **Scope inside this repo**:
  - `Tests/SwiftWebUITests/` (host unit tests, swift-testing).
  - `Tests/SwiftWebUISnapshots/` (graph-level snapshots, committed
    to git).
  - `Tests/SwiftWebUIWebDriver/` (Playwright browser smoke).
  - `.github/workflows/ci.yml` test steps (placement is
    steward's).
  - The TDD contract enforced in `.harness/docs/tdd.md`.
- **Adjacent reins**:
  - `architect` (no public symbol merges without a test pair).
  - `dom-renderer`, `bridge`, `tooling`, `docs`, `steward` —
    tester reviews and signs off the test side of every change
    those reins produce.

## Topic files you must read first

- `.harness/docs/tdd.md` — full TDD contract.
- `.harness/docs/swift-ui-surface.md` — what 0.1.0 must cover.
- `.harness/docs/js-bridge.md` — bridge test surface.

## Stop condition (project-specific)

A change is "tester-green" when:

- [ ] `swift test` is green on the host matrix.
- [ ] `swift build --triple wasm32-unknown-wasi` succeeds.
- [ ] Snapshot tests for any new graph path are present, in git,
      and unchanged unless the PR description explains the diff.
- [ ] WebDriver smoke is green on `main` and on release tags
      (skipped on PR branches when the snapshot tests are green
      — see `docs/tdd.md`).
- [ ] PR history shows red → green for the test pair.
- [ ] No public symbol landed without a corresponding test.
