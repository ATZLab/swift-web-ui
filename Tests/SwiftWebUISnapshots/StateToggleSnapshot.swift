// Tests/SwiftWebUISnapshots/StateToggleSnapshot.swift
//
// End-to-end DOM snapshot of the 0.1.0 `@State` re-render.
//
// Per `.harness/docs/tdd.md` §"Snapshot tests", this target
// hosts committed-baseline DOM-snapshot assertions. The
// baseline for a `@State` toggle is the byte string the
// renderer produces when the root view is re-evaluated after a
// mutation. In 0.1.0 the renderer is graph-based (no live DOM
// host); the "snapshot" is the serialised DOMNode tree, and
// the committed baseline is the assertion string in the test
// body.
//
// Why this lives in a dedicated target:
//   * The unit-level `@State` renderable checks in
//     `SwiftWebUIRendererTests/StateReRenderTests.swift` are
//     per-renderer-API assertions (the `_RendererReRenderHook`
//     call, the storage round-trip, the no-mutation identity).
//   * This file is the *integration* test: drive a
//     `View`-shaped value with `@State` through the public
//     `Renderer` entry point, mutate, re-render, assert the
//     committed DOM snapshot. A change to this assertion is
//     a deliberate snapshot PR with a "WHY" line in the
//     description (per `.harness/docs/tdd.md`).
//
// Owner: swiftwebui-dom-renderer (the renderer is the
// snapshot source). Architect owns the public `View` /
// `@State` surface; reviewer is the architect. See
// `.harness/docs/tdd.md` and
// `.harness/docs/swift-ui-surface.md` §10.
//
// NOTE: the 0.1.0 `SwiftWebUI.View` protocol / `Text` /
// `ViewBuilder` do not land until the 0.1.0 surface ships, so
// the snapshot test uses a minimal `Renderable` stand-in
// (per the pattern in
// `Tests/SwiftWebUIRendererTests/TextHiSnapshotTests.swift`).
// When the real `View` lands in a follow-up PR, this test
// will be rewritten against it (the assertion string stays
// the same — the snapshot is the contract, not the view
// type).

import Testing
@_spi(SwiftWebUI) @testable import SwiftWebUIRenderer
@_spi(SwiftWebUI) @testable import SwiftWebUI

/// A `Renderable` that displays the integer the wrapped
/// `State` is currently holding. Same shape as the
/// `StateDisplayView` in
/// `SwiftWebUIRendererTests/StateReRenderTests.swift`, kept
/// here as a separate type to make the snapshot target
/// self-contained (the snapshot test should not depend on
/// sibling-target types).
private struct StateToggleView: Renderable {
    let state: State<Int>

    var _renderableDescription: RenderableDescription {
        .text("count = \(state.wrappedValue)")
    }
}

@Suite("@State toggle snapshot (0.1.0 close-out)", .serialized)
struct StateToggleSnapshot {
    /// The committed DOM snapshot for the initial render.
    ///
    /// A change to this string is a deliberate snapshot PR —
    /// the snapshot is the contract (per
    /// `.harness/docs/tdd.md` §"Snapshot tests").
    private static let initialSnapshot = "<div>count = 0</div>"

    /// The committed DOM snapshot for the post-mutation render.
    private static let mutatedSnapshot = "<div>count = 1</div>"

    @Test("initial render snapshot is <div>count = 0</div>")
    func initialRenderSnapshot() {
        let state = State<Int>(wrappedValue: 0)
        let view = StateToggleView(state: state)

        let rendered = SnapshotRenderer().render(view)
        #expect(String(describing: rendered) == Self.initialSnapshot)
    }

    @Test("post-mutation render snapshot is <div>count = 1</div>")
    func postMutationRenderSnapshot() {
        let state = State<Int>(wrappedValue: 0)
        let view = StateToggleView(state: state)

        // Install a recorder that captures the renderer-side
        // re-render notification. The 0.1.0 contract is that
        // the hook fires on every `@State.wrappedValue` write;
        // the snapshot assertion below depends on the
        // renderer being *informed* of the mutation, even
        // though the snapshot target has no live DOM host
        // (the assertion is on the post-re-render graph, not
        // on the hook's call count — the unit-level test in
        // `SwiftWebUIRendererTests/StateReRenderTests.swift`
        // owns the hook-count assertion).
        let recorder = RootReRenderRecorder()
        let previous = _RendererReRenderHook.install(recorder.fire)
        defer {
            // Restore the previous hook (or uninstall if the
            // suite started without one) so the install does
            // not leak into other tests.
            if let previous {
                _RendererReRenderHook.install(previous)
            } else {
                _RendererReRenderHook.uninstall()
            }
        }

        // Mutate the state — the renderer is notified (we
        // record the notification, we do not act on it for
        // the snapshot assertion).
        state.wrappedValue = 1

        // Re-render the same view. The "single, root
        // re-render" contract (`.harness/docs/swift-ui-surface.md`
        // §4) is that the next render observes the new value.
        let rendered = SnapshotRenderer().render(view)
        #expect(String(describing: rendered) == Self.mutatedSnapshot)

        // The renderer-side hook fired exactly once for the
        // one write. This is the cross-check between the
        // unit test (which asserts the hook fires) and the
        // snapshot test (which asserts the graph reflects
        // the mutation). Both have to be true for the
        // 0.1.0 contract to hold end-to-end.
        #expect(recorder.callCount == 1)
    }
}

// MARK: - Test support

/// Test-only recorder that counts hook invocations. Mirrors
/// the support type in
/// `SwiftWebUIRendererTests/RendererReRenderHookSupport.swift`
/// — duplicated here on purpose so the snapshot target stays
/// self-contained.
private final class RootReRenderRecorder: @unchecked Sendable {
    private(set) var callCount: Int = 0

    func fire() {
        callCount += 1
    }
}
