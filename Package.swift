// swift-tools-version:5.10
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
// JavaScriptKit version range (locked by CI Swift 5.10):
//   The CI toolchain is pinned to Swift 5.10 (see
//   `.github/workflows/ci.yml`). JavaScriptKit `0.23.0+` requires
//   `swift-tools-version:6.0` and would not build on 5.10. The
//   `[0.20.0, 0.23.0)` range is the most recent set that compiles on
//   Swift 5.10. Bumping JavaScriptKit beyond 0.23 requires bumping
//   the CI toolchain in the same change.
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
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", "0.20.0" ..< "1.0.0")
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
        )
    ]
)
