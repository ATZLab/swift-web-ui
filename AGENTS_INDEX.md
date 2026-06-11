# SwiftWebUI — Agent Index

> **Quick-reference index** for the SwiftWebUI project. Three
> things: who the team is, what the baseline already says, and
> what Phase 0 should do next.
>
> For the full project brain, read [`AGENTS.md`](AGENTS.md) at the
> repo root. For the orchestrator's routing rules, read
> [`.harness/AGENTS.md`](.harness/AGENTS.md). For each rein's
> project-side wrapper, see
> [`.harness/reins/<name>/agent.md`](.harness/reins/).

---

## A. Agent squad

The 7 working agents for SwiftWebUI. All are **global** Mavis agents
that live under `~/.mavis/agents/swiftwebui-*/` and are imported
into this project as local reins under `.harness/reins/`. Routing
in `.harness/AGENTS.md` references them by `name:`.

| # | Name | Scope (one line) | Stop condition (one line) | Disk path |
|---|------|------------------|---------------------------|-----------|
| 1 | `swiftwebui-architect` | Public API surface, `_Graph` model, renderer model choice, SPI gating, DocC catalog tree | Public API surface draft is locked in `AGENTS.md` → Locked Decisions; `.docc/` has a `Getting Started.md` topic and a top-level landing page; `Renderer` protocol is declared in source | [`~/.mavis/agents/swiftwebui-architect/agent.md`](https://github.com) · [`.harness/reins/architect/agent.md`](.harness/reins/architect/agent.md) |
| 2 | `swiftwebui-dom-renderer` | `_Graph` → DOM mapping, diff/patch, list/keyed reconciliation, event delegation, DOM-side state caching | `Text("hi")` mounts to `<div>hi</div>` with a snapshot test that proves it; `swift test` is green on the full matrix; the diff/patch engine has a baseline same-input-renders-twice test | [`~/.mavis/agents/swiftwebui-dom-renderer/agent.md`](https://github.com) · [`.harness/reins/dom-renderer/agent.md`](.harness/reins/dom-renderer/agent.md) |
| 3 | `swiftwebui-bridge` | JavaScriptKit interop, `JSClosure` retain policy, Swift↔JS value conversion, `await jsPromise(_:)`, external JS binding DSL | At least one of `window.alert` / `console.log` / `fetch` has a safe Swift API; a unit test creates a `Bridge.Owner`, drops it, and asserts the JS closure is released | [`~/.mavis/agents/swiftwebui-bridge/agent.md`](https://github.com) · [`.harness/reins/bridge/agent.md`](.harness/reins/bridge/agent.md) |
| 4 | `swiftwebui-tooling` | `Package.swift` matrix, JS bundler, dev server, `scripts/serve.sh`, README Quickstart wiring | `./scripts/serve.sh` exists, is executable, builds wasm + bundles JS + serves the example on a clean clone; `swift build` and `swift test` are green on the matrix | [`~/.mavis/agents/swiftwebui-tooling/agent.md`](https://github.com) · [`.harness/reins/tooling/agent.md`](.harness/reins/tooling/agent.md) |
| 5 | `swiftwebui-docs` | `///` DocC + `## Discussion` + `## Example` on every public symbol, `.docc/` catalog tree, Apple-voice tutorials, GitHub Pages export | `swift package generate-documentation` finishes with zero warnings; a `Getting Started` `Tutorial.tutorial` exists and is referenced from the landing page; Pages deploy is wired in CI | [`~/.mavis/agents/swiftwebui-docs/agent.md`](https://github.com) · [`.harness/reins/docs/agent.md`](.harness/reins/docs/agent.md) |
| 6 | `swiftwebui-tester` | `swift-testing` skeleton, DOM snapshot harness, Playwright/WebDriver smoke, TDD enforcement, CI matrix | `swift test` green on host with zero failures and zero skipped; a Playwright smoke against the served example passes and is wired in CI; a `Text("hi") → <div>hi</div>` snapshot test exists | [`~/.mavis/agents/swiftwebui-tester/agent.md`](https://github.com) · [`.harness/reins/tester/agent.md`](.harness/reins/tester/agent.md) |
| 7 | `swiftwebui-steward` | `README`, `LICENSE`, `CONTRIBUTING`, `CoC`, `SECURITY`, PR/Issue templates, SemVer, `CHANGELOG.md`, GitHub Actions (CI + Pages), 0.1.0 release tag | `0.1.0` release notes draft is ready; `.github/workflows/ci.yml` runs the tester matrix and is green on a test PR; Dependabot + Pages deploy are wired | [`~/.mavis/agents/swiftwebui-steward/agent.md`](https://github.com) · [`.harness/reins/steward/agent.md`](.harness/reins/steward/agent.md) |

> **Note on disk paths.** The first link in the *Disk path* column
> is the **global** Mavis agent (`~/.mavis/agents/<name>/agent.md`).
> The second link is the **local rein** stub (`.harness/reins/<name>/agent.md`).
> The global file is the canonical system prompt; the local file
> adds project-side acceptance criteria and topic-file references
> and does **not** redefine the global spec. Routing is always by
> the global `name:`.

---

## B. Project baseline

What is already on disk and what it locks down. Both files were
authored in the bootstrap (`init-harness-swift-web-ui` track) and
the 7 agents were authored in parallel (`create-7-agents` track);
neither was modified by this integration pass.

### Files

- **`AGENTS.md` (project brain, repo root)** — project description,
  target repository layout, 8 locked decisions, build-and-test
  commands, team routing table, banned-list (Tokamak stack, second
  JS-bridge dependency, etc.), pointers to the orchestrator and
  topic files.
- **`.harness/AGENTS.md` (orchestrator routing)** — what the
  harness owns, the 7 rein roster (with the topic files each rein
  must read), 7 routing rules, cross-rein protocols, direct-vs-
  delegate rules, verification protocol, onboarding checklist.
- **`.harness/agent.md`** — orchestrator frontmatter so the daemon
  resolves `.harness/` as a project agent.
- **`.harness/docs/swift-ui-surface.md`** — 0.1.0 public surface
  ledger: `View`, `body`, `Text`, `VStack`/`HStack`/`ZStack`,
  `Group`, `ForEach`, `Color`, `Spacer`, `Divider`, `@State` /
  `@Binding` / `@Environment`, plus the named modifiers.
- **`.harness/docs/naming.md`** — Apple-like naming rules,
  SwiftUI↔SwiftWebUI disambiguation table, banned
  (`Tokamak*`, `*Compat`, `JS*`).
- **`.harness/docs/tdd.md`** — TDD contract: red-first, snapshot
  policy, CI matrix, `swift-testing` `@Suite` layout.
- **`.harness/docs/docc.md`** — DocC contract: `///` + `## Discussion` +
  `## Example` template, Apple-voice tone rules, catalog layout.
- **`.harness/docs/js-bridge.md`** — JavaScriptKit interop rules,
  `JSClosure` lifetime, async helpers, banned alternatives (the
  Tokamak stack and its bundler).
- **`.harness/docs/release.md`** — SemVer policy, milestone plan,
  release-note template, 0.1.0 / 0.2.0 / 0.3.0 scope.
- **`.harness/docs/repo-layout.md`** — what goes where in the
  target tree.
- **`.harness/reins/<name>/agent.md` (×7)** — project-side stubs
  for the 7 reins. Each imports its global `swiftwebui-*` agent
  and adds project-specific acceptance criteria.
- **`.harness/memory/MEMORY.md`** — shared team memory, empty.
- **`.harness/changelogs/README.md`** — per-day changelog format.

### Locked decisions (encoded in `AGENTS.md` and `.harness/docs/`)

1. **Package name** = `swift-web-ui`; products = `SwiftWebUI`,
   `SwiftWebUIRenderer`, `SwiftWebUIBridge`, `SwiftWebUITooling`.
2. **Apple-like Swift naming** — SwiftUI's exact public types and
   modifier names; typealiases over renames; no `Tokamak*`, no
   `*Compat`, no `JS*`.
3. **Apple-style DocC** — `///` + `## Discussion` / `## Example`,
   declarative tone, no second person, no marketing copy.
4. **TDD is mandatory** — tests written first, red→green in PR
   history, `swift-testing`, snapshot tests, WebDriver smoke.
5. **JavaScriptKit is the only JS-bridge dependency** — no Tokamak
   stack, no Tokamak-era bundler. Enforced by the bridge rein.
6. **Renderer model = graph-based (VDOM)** for 0.1.0; fine-grained
   reactivity is a 0.3.0+ possibility.
7. **SPI gating** — unstable surface is `@_spi(Experimental) public …`.
8. **SemVer** — `0.MINOR.PATCH` until 1.0.0.

### Routing (encoded in `.harness/AGENTS.md`)

| Work | Global agent | Local rein |
|---|---|---|
| framework design / API surface | `swiftwebui-architect` | `.harness/reins/architect/` |
| `_Graph` → DOM, diff/patch, events | `swiftwebui-dom-renderer` | `.harness/reins/dom-renderer/` |
| JavaScriptKit interop | `swiftwebui-bridge` | `.harness/reins/bridge/` |
| build / dev / JS bundle | `swiftwebui-tooling` | `.harness/reins/tooling/` |
| DocC + guides | `swiftwebui-docs` | `.harness/reins/docs/` |
| TDD, snapshots, CI | `swiftwebui-tester` | `.harness/reins/tester/` |
| OSS health, releases | `swiftwebui-steward` | `.harness/reins/steward/` |

All 7 task-spec mappings are present and correct; no update to
`.harness/AGENTS.md` was needed in this integration pass.

---

## C. Phase 0 plan summary

Phase 0 turns the locked-decision baseline into a buildable "Hello,
web in Swift" — the smallest SwiftWebUI that proves the
JavaScriptKit-on-wasm pipeline end-to-end and that exercises every
rein's stop condition at least once. The team is the 7 agents
above; tooling drives the matrix, architect gates the surface,
tester owns the red→green cycle, and the others fill in their
slice. The deliverables, in the order they should land:

1. **`Package.swift` skeleton** (owner: `swiftwebui-tooling`) — one
   SwiftPM package with four products (`SwiftWebUI`,
   `SwiftWebUIRenderer`, `SwiftWebUIBridge`, `SwiftWebUITooling`),
   a `wasm32-unknown-wasi` build target, and a host-triple test
   target. Stops when `swift build` succeeds on the host triple
   and `./scripts/serve.sh` exists, is executable, and rebuilds
   the `.wasm` + JS bundle on a clean clone.

2. **Smallest SwiftUI surface** (owner: `swiftwebui-architect`,
   reviewed by `swiftwebui-dom-renderer`) — `protocol View { … }`,
   `@ViewBuilder`, `Text`, `VStack`, plus a `Renderer` protocol
   declared in source. No `Text(...)` body yet — just the types
   and a `_ViewOutputs` skeleton. Stops when the surface draft is
   written into `AGENTS.md` under Locked Decisions and a stub
   `Renderer` declaration compiles.

3. **First failing test → first passing test cycle** (owner:
   `swiftwebui-tester`, with `swiftwebui-dom-renderer`) — TDD
   red-first: a `swift-testing` `@Suite` for `SwiftWebUI.Text`
   whose `Text("hi") → <div>hi</div>` snapshot test **fails** in
   commit 1 and **passes** in commit 2. Architect must approve the
   test name. Stops when `swift test` is green on the host triple
   with zero failures and zero skipped, and a DOM snapshot
   baseline for `<div>hi</div>` is checked in under
   `Tests/SwiftWebUISnapshots/`.

4. **DocC "Getting Started" stub** (owner: `swiftwebui-docs`) — a
   `.docc/SwiftWebUI.docc/SwiftWebUI.md` landing page, an
   `Essentials/GettingStarted.md` article, and a
   `Tutorials/Getting Started.tutorial` file that walks the user
   through `Text("Hello, web")` rendering on screen. Stops when
   `swift package generate-documentation` finishes with zero
   warnings on the new surface and the tutorial is referenced
   from the landing page.

5. **GitHub repo tree baseline** (owner: `swiftwebui-steward`,
   with `swiftwebui-tooling`) — the directory tree that the rest
   of the project will hang off: `README.md`, `LICENSE`
   (Apache-2.0, the default recommended in `.harness/docs/release.md`),
   `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`,
   `.github/ISSUE_TEMPLATE/{bug,feature,question}.md`,
   `.github/PULL_REQUEST_TEMPLATE.md`, `.github/dependabot.yml`,
   and a `.github/workflows/ci.yml` that runs `swift test` on
   the host triple. Stops when a test PR goes green against that
   CI and the README's Quickstart section actually works when
   followed verbatim.

By the end of Phase 0, "Hello, web in Swift" renders in a browser,
the test suite proves it, the docs explain how to run it, and the
repo is shaped for the 0.2.0 work (state, binding, environment,
and the first real layout modifiers) to land without further
scaffolding.

> **The full roadmap (MVP-first, stop conditions per minor, what's
> intentionally NOT on the map) lives in `ROADMAP.md` at the repo
> root.** This plan = the first stop conditions of v0.1.0.
