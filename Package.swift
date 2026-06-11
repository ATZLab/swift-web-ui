// swift-tools-version:6.0
//
// Package.swift — swift-web-ui
//
// Locked decisions (see AGENTS.md §1):
//   - Package name: swift-web-ui
//   - Products: SwiftWebUI, SwiftWebUIRenderer, SwiftWebUIBridge, SwiftWebUITooling
//   - JavaScriptKit is the only allowed JS-bridge dependency (AGENTS.md §5).
//
// Build matrix (this iteration):
//   - Host triple (macOS): `swift build` / `swift test` — runs unit tests
//     and is the CI matrix for now.
//   - WebAssembly: `swift build --triple wasm32-unknown-wasi` — optional
//     in CI, included in the local dev workflow (`scripts/serve.sh`).
//     wasm32 is not a SwiftPM platform; it is a triple. JavaScriptKit
//     gates wasi-specific code via `.unsafeFlags(...).when(platforms: [.wasi])`
//     and links the appropriate C runtime for the target triple.
//
// Toolchain / dependency version policy:
//   - Swift 6.0+ is the supported toolchain (see `.github/workflows/ci.yml`).
//     The previous Swift 5.10 line failed the test matrix because
//     `swift-testing` is not a first-party module on 5.10 — `import Testing`
//     requires either an explicit `swift-testing` package dependency on
//     5.10, or a Swift 6.0+ toolchain where `Testing` is stdlib. We
//     chose the latter to avoid dragging a third-party test framework.
//   - JavaScriptKit is pinned to `exact: "0.54.1"` (released
//     2026-06-09). The 0.x line does not honour SemVer — every
//     minor bump is treated as potentially API-breaking (see the
//     JSClosure lifetime / JSValue constructor drift warnings in
//     `.harness/docs/js-bridge.md`). The previous pin
//     `from: "0.23.0"` was the floor for Swift 6.0 compatibility;
//     we move to exact-pinned at the latest 0.x release and bump
//     deliberately per change. Bumping the version requires:
//       (1) re-verify the JSClosure retain policy in
//           `.harness/docs/js-bridge.md` against the new
//           `JSClosure` API (the registry / weak-table pattern has
//           shifted across the 0.x line).
//       (2) re-run the JSValue construction test in
//           `Sources/SwiftWebUIBridge/` if/when it lands.
//       (3) update this comment.
//
// Owner: swiftwebui-tooling.

import PackageDescription

let package = Package(
    name: "swift-web-ui",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Public, opinionated SwiftUI-style API. Empty for now; the
        // first public symbol lands in 0.1.0.
        .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),

        // Graph → DOM, diff/patch, event delegation. Owned by
        // swiftwebui-dom-renderer. Empty target until 0.1.0 lands.
        .library(name: "SwiftWebUIRenderer", targets: ["SwiftWebUIRenderer"]),

        // JavaScriptKit interop. Owns the `JSClosure` retain policy.
        // Empty target until 0.1.0 lands.
        .library(name: "SwiftWebUIBridge", targets: ["SwiftWebUIBridge"]),

        // Build / dev-server glue. Owned by swiftwebui-tooling.
        // Empty target for this iteration; the dev script
        // (`scripts/serve.sh`) is a shell script, not Swift.
        .library(name: "SwiftWebUITooling", targets: ["SwiftWebUITooling"])
    ],
    dependencies: [
        // AGENTS.md §5: JavaScriptKit is the only allowed JS-bridge dep.
        // Pinned to exact 0.54.1 (released 2026-06-09). See the
        // "Toolchain / dependency version policy" header above for
        // why we use `exact:` and the bump checklist.
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", exact: "0.54.1")
    ],
    targets: [
        .target(
            name: "SwiftWebUI",
            dependencies: []
        ),
        .target(
            name: "SwiftWebUIRenderer",
            dependencies: []
        ),
        .target(
            name: "SwiftWebUIBridge",
            dependencies: [
                .product(name: "JavaScriptKit", package: "JavaScriptKit")
            ]
        ),
        .target(
            name: "SwiftWebUITooling",
            dependencies: []
        ),
        .testTarget(
            name: "SwiftWebUITests",
            dependencies: [
                "SwiftWebUI"
            ]
        ),
        // Renderer-owned test target. Hosts the snapshot tests for
        // the v0.1.0 minimal slice (Text → <div>...</div>). The
        // dom-renderer rein owns the test files; tester reviews.
        // See `.harness/docs/tdd.md` and `ROADMAP.md` v0.1.0.
        .testTarget(
            name: "SwiftWebUIRendererTests",
            dependencies: [
                "SwiftWebUIRenderer"
            ]
        )
    ]
)
