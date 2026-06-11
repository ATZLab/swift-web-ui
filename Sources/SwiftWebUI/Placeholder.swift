// Sources/SwiftWebUI/Placeholder.swift
//
// The single public symbol exposed by `SwiftWebUI` for this iteration.
// Real public surface (`View`, `body`, `ViewBuilder`, `Text`, etc.)
// lands in 0.1.0 — see `.harness/docs/swift-ui-surface.md` and
// `ROADMAP.md`. This placeholder exists so that:
//   - `swift build` produces a library that depends on nothing
//     JavaScriptKit-side, keeping the host test matrix fast.
//   - The package products are declared in `Package.swift` exactly as
//     AGENTS.md §1 requires, even before the public surface is ready.
//   - A smoke test in `Tests/SwiftWebUITests/HelloSmokeTests.swift`
//     can prove the host build pipeline end-to-end.
//
// Owner: swiftwebui-tooling. TDD note: this placeholder is the only
// allowed public surface in this iteration; the real surface lands
// through the test-first cycle owned by swiftwebui-tester.

/// A namespace that exposes the v0.1.0 release tagline.
///
/// The constant is the smallest possible public symbol: a single
/// `static let` string. It exists to keep the package's host build,
/// test target, and DocC pipeline wired end-to-end before the real
/// `View` / `Text` / `VStack` surface lands in 0.1.0.
///
/// ## Overview
///
/// The release tagline is fixed for the lifetime of v0.1.0 and is
/// referenced from the host smoke test, the DocC `GettingStarted`
/// tutorial, and the rendered "Hello, web in Swift" web example.
/// Treating it as a typed constant — rather than a free-floating
/// string literal in each of those call sites — guarantees they all
/// stay in lockstep.
///
/// ## Example
///
/// ```swift
/// import SwiftWebUI
///
/// let banner = SwiftWebUIHello.text
/// // banner == "Hello, web in Swift"
/// ```
public enum SwiftWebUIHello {
    /// The v0.1.0 release tagline.
    public static let text: String = "Hello, web in Swift"
}
