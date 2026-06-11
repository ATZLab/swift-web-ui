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

### 11. v0.1.0 public surface is locked in `docs/swift-ui-surface.md`

- The canonical v0.1.0 SwiftUI surface — every public symbol a
  user can import, with its signature, a DocC `## Discussion`
  paragraph, the SwiftUI counterpart it mirrors, and a working
  `## Example` snippet — lives in
  **`.harness/docs/swift-ui-surface.md`**.
- That file is the **single source of truth** for what ships in
  0.1.0. Anything not enumerated there is **not** a 0.1.0 goal.
  Items the file lists as `@_spi(Experimental)` are SPI, not
  stable public surface, and MUST NOT be relied on from
  outside the SwiftWebUI source tree.
- The 0.1.0 surface is intentionally a **proof of shape**, not a
  proof of feature. The renderer is graph-based (VDOM-style,
  see §6); only `@State` is wired to a single, root re-render
  in 0.1.0. Subtree-scoped, batched re-render, `Button`,
  `onTapGesture`, gesture-driven state changes, animation,
  accessibility, and shape primitives all live in later
  milestones — see `ROADMAP.md` for the per-minor stop
  conditions.
- **Any change** — adding, removing, renaming, re-signaturing,
  or re-scoping (e.g. promoting an SPI symbol to public) — is a
  **breaking change** to the v0.1.0 contract and requires:
  1. a written rationale filed in `.harness/docs/architecture/`
     (or as an inline design note referenced from the spec);
  2. an update to `.harness/docs/swift-ui-surface.md` that
     keeps the per-symbol catalog shape (signature, Discussion,
     Mirrors SwiftUI, Example);
  3. sign-off from `swiftwebui-architect` in the PR
     description;
  4. a TDD red → green commit pair (see §4 and
     `.harness/docs/tdd.md`).
  No source change to `Sources/SwiftWebUI/**` lands in `main`
  without all four.
- The `swiftwebui-docs` agent consumes this spec to author the
  `///` DocC comments and the `.docc/` catalog. The
  `swiftwebui-tester` agent consumes this spec to author the
  per-symbol test plan and the snapshot baselines. The
  `swiftwebui-dom-renderer` agent consumes the modifier and
  container entries to scope the renderer work. None of those
  agents may diverge from the spec without re-running this
  locked-decision process.
- The architect's extension protocol (how to add a new symbol
  to the spec) is documented in `.harness/docs/swift-ui-surface.md`
  §12.

### 10. Repository-relative paths only — no absolute filesystem paths in tracked files

- **All paths in tracked docs (`AGENTS.md`, `ROADMAP.md`, `AGENTS_INDEX.md`,
  `.harness/**/*.md`, etc.) MUST be relative to the repo root.**
- Use `./foo/bar.md`, `../AGENTS.md`, `Sources/SwiftWebUI/View.swift`,
  or `docs/<topic>.md`. Never `/Users/...`, never `~/projects/...`,
  never `C:\...`.
- **Why**: this is an open-source repo. A clone on a contributor's
  machine must read identically to a clone on yours. Absolute paths
  leak the original developer's home directory and break the moment
  the project moves.
- **CI guard**: a small pre-commit / pre-merge hook (or, simpler, a
  `make lint-paths` / `swift run` script owned by `swiftwebui-tooling`)
  greps for `^/Users/`, `^/home/`, `^C:\\`, `~/` in tracked `.md` and
  fails the PR. Owner: `swiftwebui-tooling`. Stop condition for the
  guard: `make lint-paths` returns non-zero on any tracked doc that
  contains a forbidden path pattern.
- The only legitimate place for an absolute path is inside a **shell
  command** (e.g. `swift build --package-path /abs/path` in CI), never
  in prose pointing at a file inside this repo.

### 9. Git workflow — feature branches, push as PR, owner merges on GitHub

- **Default branch**: `main` is the integration branch. **No direct
  commits to `main`** — every change lands through a feature branch
  → push to `origin` → GitHub PR → owner reviews and merges on
  github.com.
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
- **Mavis workers (hard rule)**: a worker NEVER runs
  `git checkout main`, NEVER runs `git merge …` into `main`, and
  NEVER runs `git push origin main`. The worker's job ends at:
  1. commit on the feature branch,
  2. `git push -u origin <branch>`,
  3. report the PR URL (constructed as
     `https://github.com/<owner>/<repo>/pull/new/<branch>` if the
     push output didn't include one).
  Use `scripts/finish-task.sh` (owned by `swiftwebui-tooling`) — it
  does exactly the three steps above and refuses to run if the
  caller is on `main`. If a worker somehow finds itself on `main`
  mid-task, it stops and reports; it does not `git checkout -b`
  on top of an unrelated main.
- **Owner (you, via Mavis root)**: opens the PR on GitHub, reads the
  diff, runs the lint / test / smoke checks locally if needed, and
  merges on github.com. The owner is the **only** entity that
  moves code into `main`.
- **No "merge locally to make main point at the new commit"
  shortcut.** That defeats the entire point of a code-review PR
  and breaks `git log --first-parent main` as a release audit
  trail. From this commit forward, every merge into `main` is a
  GitHub PR merge.
- **One branch per concern.** A PR fixing `renderer-null-child`
  should not also sneak in an unrelated `bridge-js-closure`
  refactor. Split it.
- See `.harness/docs/release.md` for the merge / release procedure.

### 11. One PR per Phase — train-branch workflow

- **One phase = one PR**, not one PR per worker. Phase 0
  delivered 4 PRs because we did not yet have this rule; from
  Phase 1 (v0.2.0) forward, every phase opens **exactly one**
  PR on github.com.
- **Mechanics**: a phase's first worker creates a single
  `feature/<phase>-<name>` branch off `main`. Subsequent workers
  in the same phase work directly on that branch and push their
  commits to the same branch. Only the **last** worker (or the
  owner) calls `scripts/open-pr.sh` to open the single PR.
- **Workers in the same phase coordinate via `mavis communication
  send`**, NOT via separate branches. They share the train
  branch. The `scripts/finish-task.sh` and `scripts/open-pr.sh`
  guards (refuse on main, refuse if not pushed) are the safety
  net against accidental direct-to-main writes.
- **One branch per concern** still holds: a phase is one
  vertical slice of the project. Concerns inside a phase land
  as separate commits on the same branch, not as separate
  PRs.
- **Rationale**: review/merge burden is O(1) per phase instead
  of O(N) per worker. The trade-off is that the train branch
  has stacked commits — a reviewer sees them all at once on
  github.com, which is closer to "one logical change" anyway.
- **Stop conditions for this rule**:
  - The first worker of a phase creates the train branch
    (`git checkout -b feature/<phase>-<name>` off `main`).
  - All subsequent workers of the same phase do
    `git checkout feature/<phase>-<name>` at the start, NOT a
    new branch.
  - Each worker uses `scripts/finish-task.sh` (which refuses
    main) to push.
  - Exactly one `scripts/open-pr.sh` invocation per phase,
    called by the last worker or the owner.
  - The PR is opened with `--base main` and `--head
    feature/<phase>-<name>`. The PR body is auto-generated by
    `open-pr.sh` (see §12).

### 12. PR body auto-fill — `scripts/open-pr.sh`

- The project's `.github/PULL_REQUEST_TEMPLATE.md` requires a
  per-rein review checklist + per-day changelog confirmation +
  DocC + TDD confirmation. Filling this by hand is friction.
- `scripts/open-pr.sh` (owned by `swiftwebui-tooling`):
  1. Refuses to run on `main` / `master` (exit 2).
  2. Verifies the current branch is pushed to `origin`
     (refuses if not — calls `finish-task.sh` first).
  3. Reads commit subjects on the train branch and
     auto-detects which `swiftwebui-*` reins contributed (by
     keyword match on the subject line).
  4. Composes a PR body with the auto-detected reins, a
     partially-checked review checklist (auto-checks items
     that the script can verify; leaves human-judgment items
     unchecked for the owner to tick on github.com), and a
     phase/milestone pointer to ROADMAP.md.
  5. Calls `gh pr create --base main --head <branch>
     --body-file <generated>` and prints the resulting PR URL.
- **Requires `gh` CLI** installed and authenticated
  (`gh auth login`). On a fresh box the script refuses with
  a clear message — never opens a PR silently.
- **Known limitation**: the body is generated *at open time*.
  Pushing additional commits after the PR is open does not
  re-run the script; the body is fixed. This is a GitHub
  design constraint, not a tooling bug. If the phase adds
  commits after opening, the owner may run
  `gh pr edit --body-file <new>` manually.
- **Stop conditions for this rule**:
  - Every phase opens exactly one PR via `scripts/open-pr.sh`.
  - No worker types a hand-written PR title or body.
  - The PR body always includes the auto-detected reins list,
    even if empty.

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
- **Roadmap (MVP-first increments + stop conditions)**: `ROADMAP.md`
- **Path hygiene guard**: `scripts/lint-paths.sh` — run before any PR.
  Wires into the `swiftwebui-tooling` CI matrix.
- Per-day change log: `.harness/changelogs/`
- Shared team memory: `.harness/memory/MEMORY.md`
