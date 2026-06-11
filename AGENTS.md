# swift-web-ui — AGENTS.md

> Project brain for the **swift-web-ui** repository. Read this first.
> See also: `.harness/AGENTS.md` (orchestrator routing) and `.harness/docs/` (topic files).

## Project description

**SwiftWebUI** is an open-source, SwiftUI-style declarative UI framework for the
web, built on top of **JavaScriptKit** and the **Wasm** target (`wasm32-unknown-wasi` /
Swift's upcoming official `wasm32` target).

It is the spiritual successor to **TokamakUI**, now that:

- **Tokamak** is officially deprecated by its maintainers.
- The **Tokamak-era bundler** (the wasm bundler that shipped with
  Tokamak) is deprecated and no longer maintained.

JavaScriptKit is the modern, actively-maintained replacement and is the **only**
JS-bridge dependency this project is allowed to use.

The goal is a Swift API surface that, where it overlaps with SwiftUI, looks and
reads exactly like SwiftUI — same types, same modifier chains, same naming —
so that an iOS engineer can write a web view in Swift and feel at home.

## Repository layout (target shape)

```
swift-web-ui/
├── AGENTS.md                       # this file — project brain + locked decisions
├── Package.swift                   # SwiftPM manifest, wasm32 + native matrix
├── README.md                       # OSS landing page
├── CONTRIBUTING.md                 # contribution guide
├── CODE_OF_CONDUCT.md              # community standards
├── LICENSE                         # OSS license (TBD — see swiftwebui-steward)
├── .docc/                          # DocC catalog (Getting Started, etc.)
├── Sources/
│   ├── SwiftWebUI/                 # public API (View, body, modifiers, state)
│   ├── SwiftWebUIRenderer/         # _Graph, diff/patch, event delegation
│   ├── SwiftWebUIBridge/           # JavaScriptKit interop, JSClosure policy
│   └── SwiftWebUITooling/          # dev-server glue, JS bundle script
├── Tests/
│   ├── SwiftWebUITests/            # unit tests (swift-testing)
│   ├── SwiftWebUISnapshots/        # DOM snapshot tests
│   └── SwiftWebUIWebDriver/        # browser smoke (Playwright)
├── web/
│   ├── index.html                  # host page
│   └── main.js                     # bootstrap (rollup/esbuild output)
├── scripts/
│   └── serve.sh                    # one-shot dev workflow
├── .github/
│   ├── workflows/ci.yml            # CI matrix
│   └── workflows/docs.yml          # DocC → GitHub Pages
└── .harness/                       # this project's Mavis team config
    ├── AGENTS.md                   # orchestrator routing
    ├── docs/                       # topic files (locked decisions)
    ├── reins/<local-role>/         # 7 reins, each imports a swiftwebui-* global agent
    ├── changelogs/                 # per-day commit logs
    └── memory/MEMORY.md            # shared team memory
```

## Locked Decisions

These are the project's hard contracts. **Any change requires a written rationale
filed in `.harness/docs/` and approval from `swiftwebui-architect`.**

### 1. Package name and product names

- SwiftPM **package name**: `swift-web-ui`
- **Products**:
  - `SwiftWebUI` — the public, opinionated SwiftUI-style API.
  - `SwiftWebUIRenderer` — graph / diff / patch / event delegation.
  - `SwiftWebUIBridge` — JavaScriptKit interop.
  - `SwiftWebUITooling` — build / dev-server glue.
- Module map = product name. No legacy `Tokamak*` names anywhere in source.

### 2. Apple-like Swift naming (SwiftUI compatibility)

- The public surface uses SwiftUI's **exact** names wherever it makes sense:
  `View`, `body`, `some View`, `EnvironmentValues`, `EnvironmentKey`,
  `@State`, `@Binding`, `@Environment`, `@StateObject` (where applicable),
  `ViewModifier`, `Group`, `ForEach`, `ZStack`, `VStack`, `HStack`,
  `Text`, `Image`, `Button`, `Spacer`, `Divider`, `Color`, etc.
- Modifier APIs are **View extension methods** in SwiftUI's chain style:
  `.foregroundStyle(_:)`, `.padding(_:)`, `.padding()`, `.frame(width:height:)`,
  `.background(_:)`, `.font(_:)`, `.onTapGesture { ... }`.
- Type-aliases and conforming shims are preferred over renaming
  (e.g. `typealias View = SwiftWebUI.View`, not a renamed `SwiftWebUIView`).
- See `.harness/docs/naming.md` for the full rules and disambiguation list.

### 3. Apple-style documentation (DocC + inline)

- Public API uses `///` DocC comments.
- For non-trivial types, use `## Discussion` and `## Example` sections.
- **Tone is Apple guide tone**: declarative, no second-person ("you can…"),
  no marketing fluff. Sentences describe behaviour, not the reader.
- DocC catalog root lives in `.docc/`. The minimum catalog is
  "Getting Started" + "View fundamentals" + "Modifiers" + "Web Interop".
- See `.harness/docs/docc.md` for the comment template and tone rules.

### 4. TDD is mandatory

- Every public type, modifier, and renderer hook has at least one test
  **written before the implementation** lands in `main`.
- PRs are expected to show a red→green commit history for non-trivial
  changes. The `swiftwebui-tester` agent enforces this.
- swift-testing (`@Test`, `@Suite`) is the test framework of record.
- See `.harness/docs/tdd.md` for the full TDD contract.

### 5. JavaScriptKit is the **only** allowed JS-bridge dependency

- The project links against **JavaScriptKit** (`JavaScriptKit` package).
- **No Tokamak stack.** No Tokamak. No raw `JavaScriptCore`-style C bridges.
- All `JSClosure` / `JSFunction` lifetimes are owned by `SwiftWebUIBridge`
  with a documented retain policy. See `.harness/docs/js-bridge.md`.
- Any proposal to add a second JS-bridge layer — or to revive the
  Tokamak-era bundler or any of its descendants — must be rejected
  outright.

### 6. Renderer model

- The renderer is **graph-based** (VDOM-style) in 0.1.0.
  A fine-grained renderer may be considered in 0.3.0+ but is **not**
  a 0.1.0 goal.
- The graph protocol is internal (`_Graph`, `_ViewOutputs`); users never
  touch the graph directly.

### 7. SPI gating

- Unstable / in-progress surface is gated with
  `@_spi(Experimental) public …` (or `@_spi(SwiftWebUI)` for project-private SPI).
- Public, stable surface has no SPI annotation.

### 8. Versioning and release

- **Semantic versioning** (SemVer). Pre-1.0: `0.MINOR.PATCH` where MINOR may
  break source compatibility on a per-major-zero basis.
- 0.1.0 = "Hello, web in Swift" (Text + VStack + render to DOM).
- See `.harness/docs/release.md` for the milestone plan.

### 9. Git workflow — feature branches, no direct commits to `main`

- **Default branch**: `main` is the integration branch. **No direct commits
  to `main`** — every change lands through a feature branch + merge.
- **Branch naming** (Conventional Commits style, kebab-case scope):
  - `feature/<scope>-<short-desc>` — new user-facing surface (e.g.
    `feature/renderer-initial-graph`, `feature/bridge-js-closure`).
  - `fix/<scope>-<short-desc>` — bug fix (e.g. `fix/renderer-null-child`).
  - `chore/<scope>-<short-desc>` — non-functional (e.g. `chore/ci-cache`).
  - `docs/<scope>-<short-desc>` — documentation only.
  - `refactor/<scope>-<short-desc>` — internal restructuring.
  - `test/<scope>-<short-desc>` — test-only changes.
- **Scope** = the module or topic name in lowercase: `renderer`, `bridge`,
  `view`, `modifier`, `state`, `docs`, `ci`, `tooling`, `release`.
- **Mavis workers** (i.e. tasks dispatched via `mavis team plan`):
  - Receive a prompt that says "create a branch and work there" and do
    exactly that. The worker pushes the branch and reports a deliverable
    (or opens a PR). It does **not** merge to `main`.
  - The owner (you, via Mavis root) reviews the deliverable and merges.
- **One branch per concern.** A PR fixing `renderer-null-child` should not
  also sneak in an unrelated `bridge-js-closure` refactor. Split it.
- See `.harness/docs/release.md` for the merge / release procedure.

## Team routing

The 7 specialist agents for this project live in the **global** Mavis
agent registry (`~/.mavis/agents/swiftwebui-*/`). They are imported into
this project as local reins under `.harness/reins/`. The full routing
table is in `.harness/AGENTS.md`. Quick map:

| Work | Referred agent (global) | Local rein |
|---|---|---|
| Framework design / API surface | `swiftwebui-architect` | `.harness/reins/architect/` |
| `_Graph` → DOM, diff/patch, events | `swiftwebui-dom-renderer` | `.harness/reins/dom-renderer/` |
| JavaScriptKit interop | `swiftwebui-bridge` | `.harness/reins/bridge/` |
| Build / dev / JS bundle | `swiftwebui-tooling` | `.harness/reins/tooling/` |
| DocC + guides | `swiftwebui-docs` | `.harness/reins/docs/` |
| TDD, snapshots, CI | `swiftwebui-tester` | `.harness/reins/tester/` |
| OSS health, releases | `swiftwebui-steward` | `.harness/reins/steward/` |

## Build and test (target)

```bash
# host (native, used for unit tests of pure-Swift logic)
swift build
swift test

# wasm (used for the actual web app)
swift build --triple wasm32-unknown-wasi

# one-shot dev: build wasm + bundle JS + serve
./scripts/serve.sh

# docs
swift package generate-documentation
```

(Exact commands will be wired up by `swiftwebui-tooling` in Phase 0.)

## Banned

- Imports from the Tokamak-era bundler, `Tokamak*` imports, any
  reference to the deprecated Tokamak bundler stack in code or
  docs.
- Second JS-bridge dependency.
- Renaming SwiftUI types when an alias would do.
- Public surface changes without a DocC comment and at least one test.
- "I added tests later" — TDD means tests first.

## Pointers

- Orchestrator routing: `.harness/AGENTS.md`
- Locked decisions (deep dive): `.harness/docs/`
- Per-day change log: `.harness/changelogs/`
- Shared team memory: `.harness/memory/MEMORY.md`
