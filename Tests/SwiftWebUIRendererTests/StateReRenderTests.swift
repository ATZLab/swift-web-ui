// Tests/SwiftWebUIRendererTests/StateReRenderTests.swift
//
// TDD red for the 0.1.0 root re-render wiring.
//
// AGENTS.md §6 says the renderer is graph-based (VDOM-style) in
// 0.1.0. `.harness/docs/swift-ui-surface.md` §4 says mutating
// `@State.wrappedValue` "triggers a single, full re-render of the
// root view tree" in 0.1.0. This file is the test pair that
// proves that contract: the architect's real `@State` is wired
// to the renderer, and a write on `@State` causes the next
// render to reflect the new value.
//
// Three tests:
//
//   1. `stateMutationIsReflectedInNextRender` — the storage
//      semantics the `State.swift` setter already provides (a
//      write stores the new value, a subsequent read returns it)
//      are the *minimum* the renderer needs. A second
//      `SnapshotRenderer().render(_:)` call after the mutation
//      must produce a graph whose text is the new value.
//
//   2. `stateSetterTriggersRootReRenderer` — the 0.1.0 *real*
//      re-render contract: the renderer's root re-renderer is
//      invoked when `@State.wrappedValue` is set. The renderer
//      exposes a `_RendererReRenderHook` (the implementation
//      detail C2 ships), `@State` calls it from its setter, and
//      the test asserts the hook fires exactly once per write.
//
//   3. `noMutationTwoRendersAreIdentical` — the
//      "no patches" baseline that the dom-renderer rein's
//      "Stop when" rules require. Two consecutive renders of
//      the same view with no state change must produce
//      byte-identical graphs.
//
// All three are red on the first commit (the renderer does not
// yet expose the hook and the `State` setter is a TODO
// placeholder). The green commit wires both.
//
// Owner: swiftwebui-dom-renderer (the renderer is the SPI
// owner of the re-render hook). Architect owns `@State`'s
// surface; reviewer is the architect. See `.harness/docs/tdd.md`
// for the red-first rule and the per-symbol acceptance
// (`.harness/docs/swift-ui-surface.md` §10).

import Testing
@_spi(SwiftWebUI) @testable import SwiftWebUIRenderer
@_spi(SwiftWebUI) @testable import SwiftWebUI

// MARK: - Test stand-in for a SwiftWebUI.View

/// Test-local stand-in for a SwiftWebUI.View that displays a
/// single integer — the architect's `View` protocol / `Text` /
/// `ViewBuilder` do not land until the 0.1.0 surface ships, so
/// the renderer tests use a minimal conformer that maps directly
/// to the existing `RenderableDescription` enum.
///
/// Reads `state.wrappedValue` at every render so the renderer
/// sees whatever the most recent write set. This is the
/// property the re-render test is exercising: a write to the
/// wrapper, then a re-render, yields the new value.
struct StateDisplayView: Renderable {
    /// The state the view reads on every render.
    let state: State<Int>

    /// Renders the integer the state is currently holding.
    var _renderableDescription: RenderableDescription {
        .text("count = \(state.wrappedValue)")
    }
}

// MARK: - Tests

@Suite("@State root re-render (0.1.0)", .serialized)
struct StateReRenderTests {
    @Test("state mutation is reflected in the next render")
    func stateMutationIsReflectedInNextRender() {
        // Arrange: a `State<Int>` initialised to 0 and a view that
        // reads its current value.
        let state = State<Int>(wrappedValue: 0)
        let view = StateDisplayView(state: state)

        // Act 1: initial render — graph should show "count = 0".
        let firstRender = SnapshotRenderer().render(view)
        #expect(String(describing: firstRender) == "<div>count = 0</div>")

        // Act 2: mutate the state. The 0.1.0 contract is that the
        // storage is updated; the graph re-render is asserted by
        // Act 3 (a single, full re-render of the root is the
        // renderer's job, but the *minimum* the wrapper must
        // guarantee is that the value is updated and visible on
        // the next read).
        state.wrappedValue = 1

        // Act 3: re-render the same view — graph should now show
        // the new value. This is the "single, root re-render"
        // contract surfaced through the renderer's `render(_:)`
        // entry point.
        let secondRender = SnapshotRenderer().render(view)
        #expect(String(describing: secondRender) == "<div>count = 1</div>")
    }

    @Test("state setter triggers the renderer's root re-render hook")
    func stateSetterTriggersRootReRenderer() {
        // Arrange: a `State<Int>` initialised to 0.
        let state = State<Int>(wrappedValue: 0)

        // The renderer registers a hook the `@State` setter
        // invokes. The 0.1.0 implementation calls the closure
        // synchronously, exactly once per write (no batching,
        // no RAF — those are 0.2.0/0.3.0). The closure is the
        // "single, root re-render" the spec calls for.
        //
        // RED signal: the renderer does not yet expose
        // `_RendererReRenderHook`. Calling `install` here is the
        // compile error that drives the red→green cycle.
        let recorder = RootReRenderRecorder()
        _RendererReRenderHook.install(recorder.fire)

        // Act: mutate the state. The setter must invoke the
        // installed hook exactly once.
        state.wrappedValue = 1

        // Assert: the hook fired exactly once with no payload
        // (the renderer carries its own root view reference; the
        // 0.1.0 seam is a no-arg closure). The mutation is
        // observed by the renderer — that is the 0.1.0 root
        // re-render contract.
        #expect(recorder.callCount == 1)

        // Tear down: restore the previous (nil) hook so the
        // install does not leak into other tests in the suite.
        _RendererReRenderHook.uninstall()
    }

    @Test("no mutation — two consecutive renders produce identical graphs")
    func noMutationTwoRendersAreIdentical() {
        // This is the "zero patches" baseline the diff/patch
        // engine's stop condition requires (see the dom-renderer
        // rein's "Stop when" rules). In 0.1.0 the renderer is
        // graph-based with no live DOM host, so the equivalent
        // assertion is: rendering the same view twice with no
        // state change produces byte-identical DOMNode trees.
        let state = State<Int>(wrappedValue: 7)
        let view = StateDisplayView(state: state)

        let first = String(describing: SnapshotRenderer().render(view))
        let second = String(describing: SnapshotRenderer().render(view))

        #expect(first == "<div>count = 7</div>")
        #expect(first == second)
    }
}
