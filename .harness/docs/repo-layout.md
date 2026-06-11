# Repo layout — what goes where

> Owner: `swiftwebui-tooling` (paths) + `swiftwebui-steward`
> (OSS-tree parts). This file is the single source of truth for
> "where do I put X?".

## Top-level

```
swift-web-ui/
├── AGENTS.md                       # project brain + locked decisions (root)
├── Package.swift                   # SwiftPM manifest (tooling)
├── README.md                       # OSS landing page (steward)
├── CONTRIBUTING.md                 # how to contribute (steward)
├── CODE_OF_CONDUCT.md              # community standards (steward)
├── LICENSE                         # OSS license (steward)
├── .docc/                          # DocC catalog (docs)
├── Sources/                        # Swift source (see below)
├── Tests/                          # swift-testing suites (tester)
├── web/                            # host page + JS bootstrap (tooling)
├── scripts/                        # shell glue (tooling)
├── examples/                       # runnable demo apps (architect)
├── .github/                        # workflows + templates (steward)
├── .harness/                       # Mavis team config (orchestrator)
└── .opencode/                      # local OpenCode session cache (not source)
```

## `Sources/`

The package exposes four products, one directory each:

```
Sources/
├── SwiftWebUI/                     # public API
│   ├── View.swift
│   ├── ViewBuilder.swift
│   ├── Text.swift
│   ├── Stacks/{VStack,HStack,ZStack}.swift
│   ├── ForEach.swift
│   ├── Color.swift
│   ├── Spacer.swift
│   ├── Divider.swift
│   ├── State/{State,Binding,Environment}.swift
│   ├── EnvironmentValues.swift
│   └── Modifiers/
│       ├── Padding.swift
│       ├── Frame.swift
│       ├── ForegroundStyle.swift
│       ├── Background.swift
│       ├── Font.swift
│       ├── CornerRadius.swift
│       ├── OnTapGesture.swift
│       └── Opacity.swift
├── SwiftWebUIRenderer/             # graph + diff/patch + events
│   ├── _Graph.swift
│   ├── _Diff.swift
│   ├── _Patch.swift
│   ├── _EventDelegation.swift
│   └── Renderer.swift
├── SwiftWebUIBridge/               # JavaScriptKit interop (the only JS importer)
│   ├── JSClosureRegistry.swift
│   ├── BridgedClosure.swift
│   ├── Values.swift
│   ├── Async.swift
│   └── Browser/                    # typed wrappers for window.alert, console.log, fetch
└── SwiftWebUITooling/              # dev-server glue, JS bundle script
    ├── serve.swift
    └── BundleCommand.swift
```

## `Tests/`

```
Tests/
├── SwiftWebUITests/                # unit (host Swift)
├── SwiftWebUISnapshots/            # graph-level snapshot tests
└── SwiftWebUIWebDriver/            # Playwright smoke (real browser)
```

## `web/`

The host page and the JavaScript bundle that bootstraps the wasm
module.

```
web/
├── index.html                      # host page (mounts #app)
├── main.js                         # JS bootstrap (built by rollup/esbuild)
└── bundle.config.mjs               # bundle config (tooling)
```

## `scripts/`

Shell glue. One entry point per common workflow:

```
scripts/
├── serve.sh                        # build wasm + bundle JS + dev server
├── test.sh                         # host test + snapshot test
└── release.sh                      # tag + push + verify CI
```

## `examples/`

Runnable demo apps that double as visual regression targets:

```
examples/
├── Hello/                          # Text("Hello, world!") in a VStack
├── Counter/                        # @State counter with Button
└── FetchDemo/                      # bridge.fetch() from a SwiftUI Button
```

## `.harness/`

The Mavis project-team definition (this directory):

```
.harness/
├── AGENTS.md                       # orchestrator routing (human-readable)
├── agent.md                        # orchestrator frontmatter spec
├── docs/                           # topic files (locked decisions)
│   ├── swift-ui-surface.md
│   ├── naming.md
│   ├── tdd.md
│   ├── docc.md
│   ├── js-bridge.md
│   ├── release.md
│   └── repo-layout.md
├── reins/                          # local rein stubs (import global agents)
│   ├── architect/agent.md
│   ├── dom-renderer/agent.md
│   ├── bridge/agent.md
│   ├── tooling/agent.md
│   ├── docs/agent.md
│   ├── tester/agent.md
│   └── steward/agent.md
├── changelogs/                     # per-day commit logs
└── memory/MEMORY.md                # shared team memory
```

## Naming rules within the tree

- **No** `Sources/Tokamak*` directories.
- **No** `web/*bundler*config*` files that refer to the
  Tokamak-era bundler. Bundle config is `web/bundle.config.mjs`.
- **No** references to the Tokamak-era bundler in any file
  content. The `swiftwebui-bridge` agent greps for the related
  token patterns on every PR.
- File names match their primary type, PascalCase, singular
  (`Text.swift`, not `Texts.swift`).
- One public type per file is the default; tightly-coupled
  companions may share a file (e.g. `VStack.swift` may also
  define `VStackAlignment`).

## What is NOT in the tree

- `node_modules/` (git-ignored; produced by `web/bundle.config.mjs`).
- `.build/` (git-ignored; SwiftPM build dir).
- `Package.resolved` (git-ignored; resolver pin lives in the
  release lockfile instead, owned by tooling).
- `DerivedData/` (git-ignored; Xcode build dir — we don't use
  Xcode for the package, only for IDE convenience).
