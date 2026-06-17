// swift-tools-version:6.2
//
// Package.swift — swift-web-ui
//
// Locked decisions (see AGENTS.md §1):
//   - Package name: swift-web-ui
//   - Products: SwiftWebUI, SwiftWebUIRenderer, SwiftWebUIBridge, SwiftWebUITooling
//   - JavaScriptKit is the only allowed JS-bridge dependency (AGENTS.md §5).
//
// swift-tools-version rationale:
//   The manifest must declare a tools-version that meets or exceeds
//   the maximum of every dependency's own tools-version. JavaScriptKit
//   0.54.1 (our current pin) declares `swift-tools-version:6.2`, so
//   6.2 is the floor. We do not jump to 6.3 yet because no released
//   dependency requires it; 6.2 keeps the manifest portable across
//   Swift 6.2, 6.3, and 6.4 toolchains. The *compiler* version used
//   to build the package is set separately by the build toolchain
//   (Xcode 26.4.1 = Swift 6.3.1 in CI; see
//   `.github/workflows/ci.yml`) and is independent of this number.
//
// Build matrix (this iteration):
//   - Host triple (macOS): `xcodebuild` against the
//     `swift-web-ui-Package` SwiftPM scheme, on `macos-26` with
//     Xcode 26.4.1 (default). The CI workflow
//     (`.github/workflows/ci.yml`) is pinned to this toolchain so
//     that `xcodebuild build-for-testing` and `xcodebuild
//     test-without-building` exercise the same Swift compiler
//     (6.3.1) that downstream consumers will see.
//   - WebAssembly: `swift build --triple wasm32-unknown-wasi` — optional
//     in CI, included in the local dev workflow (`scripts/serve.sh`).
//     wasm32 is not a SwiftPM platform; it is a triple. JavaScriptKit
//     gates wasi-specific code via `.unsafeFlags(...).when(platforms: [.wasi])`
//     and links the appropriate C runtime for the target triple.
//
// JavaScriptKit version range (locked by CI Swift 6.3.1):
//   The CI toolchain is pinned to Swift 6.3.1 via `macos-26` + Xcode
//   26.4.1 (see `.github/workflows/ci.yml`). JavaScriptKit
//   `0.23.0+` requires `swift-tools-version:6.0` and the 0.50+
//   line (including 0.54.1, our current pin) further requires
//   `swift-tools-version:6.2`. The `[0.20.0, 1.0.0)` range is the
//   right open upper bound for a Swift 6.2+ project. Bumping
//   JavaScriptKit beyond 0.54.x is allowed in the same change as
//   the tools-version bump that the new release requires.
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
        // Range chosen for Swift 5.10 (CI) compatibility — see header.
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", "0.20.0" ..< "1.0.0"),
        // DocC build plugin. The 0.1.0 close-out introduced
        // `scripts/verify-docc.sh` as a zero-warning DocC gate wired
        // into `scripts/finish-task.sh`; that script runs
        // `swift package generate-documentation`, which is provided
        // by this plugin. `swift-docc-plugin` itself does not depend
        // on (and does not interact with) JavaScriptKit or the
        // Tokamak stack, so it does not relax AGENTS.md §5.
        //
        // Range pin: 1.0.0 → <2.0.0 covers 1.x including 1.5.0
        // (current). `swift-tools-version:5.7` is well under our
        // 6.2 floor, so the plugin builds on every supported
        // toolchain.
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SwiftWebUI",
            // The 0.1.0 root re-render wiring (C2) has
            // `@State.wrappedValue`'s setter invoke the
            // renderer's `_RendererReRenderHook.trigger()`.
            // That hook is renderer-internal SPI (see
            // `Sources/SwiftWebUIRenderer/RendererReRenderHook.swift`,
            // marked `@_spi(SwiftWebUI)`). The dep is one-way:
            // `SwiftWebUI` → `SwiftWebUIRenderer`. The renderer
            // does not import `SwiftWebUI` — its `Renderable`
            // protocol is owned by the renderer, and the
            // public `View` / `Text` surface is consumed by
            // user code (or the snapshot test stand-ins),
            // not by the renderer itself.
            dependencies: [
                "SwiftWebUIRenderer"
            ]
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
        // the v0.1.0 minimal slice (Text → <div>...</div>) and the
        // 0.1.0 re-render wiring tests (a SwiftWebUI.View with
        // `@State` mutates, the renderer re-evaluates). The test
        // target depends on `SwiftWebUI` so the tests can drive
        // the architect's real `@State` wrapper. The dom-renderer
        // rein owns the test files; tester reviews. See
        // `.harness/docs/tdd.md` and `ROADMAP.md` v0.1.0.
        .testTarget(
            name: "SwiftWebUIRendererTests",
            dependencies: [
                "SwiftWebUIRenderer",
                "SwiftWebUI"
            ]
        ),
        // Snapshot-only test target. Per `.harness/docs/tdd.md`
        // §"Snapshot tests", the dedicated `SwiftWebUISnapshots`
        // target is where committed-baseline DOM-snapshot
        // assertions live. The C2 (0.1.0 close-out) re-render
        // work lands an end-to-end snapshot of a `@State` toggle
        // here; the unit-level renderable checks remain in
        // `SwiftWebUIRendererTests` for now and will migrate as
        // the snapshot discipline matures in 0.2.0.
        .testTarget(
            name: "SwiftWebUISnapshots",
            dependencies: [
                "SwiftWebUIRenderer",
                "SwiftWebUI"
            ]
        ),
        // JavaScriptKit interop tests (v0.2.0 phase 2-4).
        // Host-runnable unit tests (JSClosureRegistry map
        // semantics + Values primitive round-trip) run on
        // the macOS / native triple; tests that need a live
        // JSKit runtime (array/object round-trip, Promise
        // await, window.alert / console.log wrappers) are
        // `#if os(WASI)`-gated inside the same suite files
        // and exercise the wasm32 host in CI. The target
        // depends on the bridge module directly so the
        // `@testable import SwiftWebUIBridge` is permitted
        // under the test target's `@_spi(SwiftWebUI)`
        // surface. See `.harness/docs/js-bridge.md` and
        // `.harness/docs/tdd.md` for the split.
        .testTarget(
            name: "SwiftWebUIBridgeTests",
            dependencies: [
                "SwiftWebUIBridge"
            ]
        )
    ]
)
