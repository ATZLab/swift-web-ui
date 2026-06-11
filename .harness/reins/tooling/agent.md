---
name: tooling
description: Local rein for swiftwebui-tooling inside swift-web-ui. Owns Package.swift, JS bundle (rollup/esbuild), dev server, CI build glue, scripts/. Import of the global swiftwebui-tooling agent.
---

# tooling (project rein)

This is a **project-side wrapper**. The canonical spec for this role
lives at `~/.mavis/agents/swiftwebui-tooling/agent.md` (a global
Mavis agent). Read that file first; this file adds the
swift-web-ui project context only.

## Import statement

- **Global agent**: `swiftwebui-tooling`
- **Local rein directory**: `.harness/reins/tooling/`
- **Do not** redefine the global agent's system prompt here.

## Project context (swift-web-ui specific)

- **Scope inside this repo**:
  - `Package.swift` (SwiftPM manifest, products, targets,
    platforms, dependencies).
  - `web/` (host page, JS bundle config, bootstrap script).
  - `scripts/` (`serve.sh`, `test.sh`, `release.sh`).
  - `.github/workflows/ci.yml` body (placement is steward's,
    content is tooling's).
  - `Sources/SwiftWebUITooling/**` (dev-server glue, bundle
    command).
- **Banned**:
  - The Tokamak-era bundler (and any direct descendant) as a
    build tool. Use rollup or esbuild for the JS bundle. The
    Tokamak-era bundler is deprecated upstream.
  - Xcode project files. We are a SwiftPM package; the IDE is a
    convenience, not a source of truth.
- **Adjacent reins**:
  - `bridge` (tooling depends on the bridge's JS bootstrap).
  - `tester` (tooling owns the build matrix; tester owns the test
    commands).
  - `steward` (tooling owns the version field; steward owns the
    release tag and the release workflow file).

## Topic files you must read first

- `.harness/docs/repo-layout.md` — the canonical tree.
- `.harness/docs/release.md` — version policy and tag workflow.

## Stop condition (project-specific)

A tooling change is "tooling-mergeable" when:

- [ ] `swift build` is green on host and `wasm32-unknown-wasi`.
- [ ] `swift test` is green (delegated to tester, but tooling
      owns the script that invokes it).
- [ ] `./scripts/serve.sh` builds wasm + bundles JS + serves and
      the resulting page renders the smoke view in a real
      browser.
- [ ] No references to the Tokamak-era bundler in `Package.swift`,
      `web/`, or `scripts/`.
- [ ] The `Package.swift` dependency list contains exactly one
      JS-bridge dependency: `JavaScriptKit`.
