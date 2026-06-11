// Tests/SwiftWebUIRendererTests/RendererReRenderHookSupport.swift
//
// Test support for the 0.1.0 root re-render hook. The hook
// itself lives in the renderer's SPI (see the green-commit
// renderer source); the recorder and any test-only helpers
// live here so the test target can install / observe it
// without leaking into production sources.
//
// Owner: swiftwebui-dom-renderer (the renderer SPI owner of the
// hook). Architect owns `@State`'s surface; reviewer is the
// architect.

import Foundation

/// Test-only recorder that counts hook invocations. Lives
/// next to the test on purpose — it is the *test's* witness,
/// not production code.
///
/// `@unchecked Sendable` because the recorder is only read
/// from the test thread (0.1.0 is single-threaded) and the
/// 0.2.0 worker-thread work will replace the hook with a
/// queue / `Mutex`-backed implementation.
final class RootReRenderRecorder: @unchecked Sendable {
    /// Number of times the hook has fired.
    private(set) var callCount: Int = 0

    /// The hook the test installs.
    func fire() {
        callCount += 1
    }
}
