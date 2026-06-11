# SwiftWebUI

> A SwiftUI-style declarative UI framework for the web, built on
> **JavaScriptKit** and the **Wasm** target.

SwiftWebUI is an open-source, SwiftUI-style declarative UI framework for the
web, built on top of **JavaScriptKit** and the **Wasm** target
(`wasm32-unknown-wasi` / Swift's upcoming official `wasm32` target). It is the
spiritual successor to **TokamakUI**, now that Tokamak and the Tokamak-era
bundler are officially deprecated. JavaScriptKit is the modern,
actively-maintained replacement and the **only** JS-bridge dependency this
project is allowed to use.

The goal is a Swift API surface that, where it overlaps with SwiftUI, looks
and reads exactly like SwiftUI — same types, same modifier chains, same
naming — so that an iOS engineer can write a web view in Swift and feel at
home.

## Status

**0.1.0 is in progress** — see [`ROADMAP.md`](./ROADMAP.md) for the MVP
stop conditions, what's in the next minors, and what is intentionally not on
the map. The 0.1.0 milestone ships a working
`Text("hi")` → `<div>hi</div>` render path with a graph-based renderer and a
hosted "Hello, web" example. License: **Apache-2.0** (see [`LICENSE`](./LICENSE)).

**0.1.0 is in progress** — see [`ROADMAP.md`](./ROADMAP.md) for the MVP
stop conditions, what's in the next minors, and what is intentionally not on
the map. The 0.1.0 milestone ships a working
`Text("hi")` → `<div>hi</div>` render path with a graph-based renderer and a
hosted "Hello, web" example.

## Quickstart

> The Quickstart below activates once the
> `feature/tooling-package-skeleton` PR is merged; see
> [`ROADMAP.md`](./ROADMAP.md) v0.1.0 stop conditions for the current
> status.

```bash
# 1. Clone
git clone https://github.com/ATZLab/swift-web-ui.git
cd swift-web-ui

# 2. Build the wasm target, bundle the JS host, and serve the example
./scripts/serve.sh
```

`./scripts/serve.sh` builds `Sources/SwiftWebUI` (and the renderer, bridge,
and tooling products) for `wasm32-unknown-wasi`, bundles the JS host page,
and serves the example on `http://localhost:8080`. A browser tab shows
`<div>Hello, web.</div>` rendered from Swift.

If the script is not yet on the branch, run `./scripts/serve.sh` after the
`feature/tooling-package-skeleton` PR is merged (see the open PR); see
[`ROADMAP.md`](./ROADMAP.md) v0.1.0 stop conditions for the current status.

## Documentation

- **[`AGENTS.md`](./AGENTS.md)** — the project brain: locked decisions,
  package name, JavaScriptKit-only rule, SemVer policy, branch workflow.
- **[`ROADMAP.md`](./ROADMAP.md)** — MVP-first increments and the per-minor
  stop conditions (v0.1.0 through v1.0.0).
- **[`.docc/`](./.docc/)** — the DocC catalog (Getting Started, View
  fundamentals, Modifiers, Web Interop). Populated by
  `swiftwebui-docs` in this round; tutorials are referenced from
  [`AGENTS.md`](./AGENTS.md).
- **[`.harness/docs/`](./.harness/docs/)** — topic files: SwiftUI surface
  ledger, naming rules, TDD contract, DocC tone rules, JavaScriptKit
  interop rules, release mechanics, repo layout.
- **`swift package generate-documentation`** — builds the DocC site from
  the `///` comments on every public symbol (zero-warning policy).

## Contributing

Contributions of all kinds are welcome — code, docs, tests, examples, and
issue triage. Read [`CONTRIBUTING.md`](./CONTRIBUTING.md) first; it covers
the dev env, the **TDD contract** (tests first, red→green in the PR
history), the branch workflow (no direct commits to `main`; feature branch
+ GitHub PR), and the commit style (Conventional Commits).

## License

SwiftWebUI is released under the **Apache License 2.0**. See
[`LICENSE`](./LICENSE) for the full text. The Apache-2.0 license is chosen
for compatibility with **JavaScriptKit's** MIT/Apache dual license and with
the **Swift** project's Apache-2.0.

## Code of conduct

This project follows the
[**Contributor Covenant, version 2.1**](`https://www.contributor-covenant.org/version/2/1/code_of_conduct/`).
See [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md) for the full text, and
[`SECURITY.md`](./SECURITY.md) for how to report a vulnerability privately.

---

> **A Swift engineer can read a SwiftWebUI file and not realize they're
> writing for the web.** — [`ROADMAP.md`](./ROADMAP.md), North star.
