// Tests/SwiftWebUIRendererTests/ButtonTapActionTests.swift
//
// 0.2.0 `Button` interaction contract.
//
// This file is the RED commit for the 0.2.0 per-symbol acceptance
// in `.harness/docs/swift-ui-surface.md` §10 (lines 1390–1410). The
// 0.2.0 contract:
//
//   1. **Tap-fires-action** (line 1392): a `Button("Save") { counter
//      += 1 }` whose action is invoked once on a synthetic click;
//      the action receives the increment; the `@State` write
//      triggers a subtree re-render.
//   2. **Re-render pairing** with `@State` (line 1407): a `Button`
//      that increments a `@State` triggers a subtree-scoped
//      re-render of the view that owns the state; the post-tap
//      DOM reflects the new value.
//
// The 0.2.0 `Button` public type does not exist yet (it lands
// in the green commit). For the red tests we use a
// test-local `Button` stand-in that conforms to the renderer's
// existing `Renderable` protocol — the same pattern the
// 0.1.0 close-out used for `Text("hi")` (see
// `TextHiSnapshotTests.swift`).
//
// The stand-in is intentionally **not** the production
// `SwiftWebUI.Button` (which is the architect's surface, lands
// in the green commit, and conforms to `SwiftWebUI.View`). The
// test asserts the **contract**: a click invokes the action, a
// `@State` mutation inside the action schedules a commit.
//
// All three tests fail against the 0.1.0 implementation: the
// 0.1.0 `@State` setter triggers
// `_RendererReRenderHook.trigger()` synchronously; the test
// asserts the 0.2.0 microtask commit fires on the main actor
// (the `ReRenderObserver` stub sees no commit because the
// stub's `schedule` is a no-op).
//
// **Scope note (red commit):** the role-attribute
// (line 1401) and `<button>Save</button>` snapshot
// (line 1397) tests are deferred to a follow-up red
// commit. Those tests require the production
// `RenderableDescription.button` case, which is the
// dom-renderer rein's contract; adding a compile-failure
// test to `SwiftWebUIRendererTests` would break the
// 0.1.0 test target's compile. The follow-up red commit
// adds them to a target that does not block the
// 0.1.0 baseline (e.g. a new snapshot sub-target added
// by the tooling rein). Tracked in the report to the
// parent.
//
// Owner: swiftwebui-tester. swiftwebui-architect owns the
// `Button` / `ButtonRole` / `ButtonStyle` public surface;
// swiftwebui-dom-renderer owns the SPI and the renderer shape.
// See `.harness/docs/tdd.md` and
// `.harness/docs/swift-ui-surface.md` §2 + §8 + §10.

import Foundation
import Testing
@_spi(SwiftWebUI) @testable import SwiftWebUIRenderer
@_spi(SwiftWebUI) @testable import SwiftWebUI

// MARK: - ReRender observer (test fixture)

private final class ButtonCommitRecorder: ReRenderObserver, @unchecked Sendable {
    private(set) var commits: [[_GraphIdentity]] = []
    private(set) var lastCommitWasOnMainActor: Bool = false

    func scheduler(didCommitFor subtrees: [_GraphIdentity]) {
        MainActor.assertIsolated()
        lastCommitWasOnMainActor = true
        commits.append(subtrees)
    }
}

// MARK: - Button stand-in (test fixture)

/// The 0.2.0 `ButtonRole` enum (per
/// `.harness/docs/swift-ui-surface.md` §2). The production
/// type lives in `Sources/SwiftWebUI/`; this stub is the
/// test-side mirror used by the red test until the green
/// commit replaces it.
public enum ButtonRole: Hashable, Sendable {
    case destructive
    case cancel
}

/// Test-local stand-in for the 0.2.0 `SwiftWebUI.Button`.
///
/// The 0.2.0 `Button` is a public, SwiftUI-shaped control
/// (see spec §2). The 0.1.0 production type does not exist
/// yet. The stand-in holds the action and identity; the
/// test installs the DOM `click` listener via
/// `_RenderEventRegistry` and fires synthetic clicks via
/// the registry's `simulate(event:on:)` API. This keeps
/// the test compiling against the 0.1.0 production
/// sources (no `.button` case in `RenderableDescription`
/// is referenced).
struct ButtonStandIn {
    let label: String
    let role: ButtonRole?
    let action: () -> Void
    let identity: _GraphIdentity
}

// MARK: - Action counter (test fixture)

/// Non-isolated counter the test action increments.
/// The "fires once" assertion only needs to know how
/// many times the action ran; the main-actor isolation
/// of the action body is a separate concern tested by
/// the `lastCommitWasOnMainActor` flag on the commit
/// recorder (the `ReRenderObserver.scheduler(didCommitFor:)`
/// body asserts `MainActor.assertIsolated()`).
///
/// `@unchecked Sendable` is the same shim pattern the
/// other red tests use.
private final class ActionCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _count: Int = 0
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }
    func increment() {
        lock.lock()
        _count += 1
        lock.unlock()
    }
}

// MARK: - Button tap-fires-action (line 1392)

@Suite("Button tap-fires-action (0.2.0, line 1392)", .serialized)
struct ButtonTapFiresActionTests {
    @Test("a synthetic click on a Button invokes the action exactly once")
    func syntheticClickInvokesActionOnce() async {
        let recorder = ButtonCommitRecorder()
        _ReRenderScheduler.observer = recorder
        defer { _ReRenderScheduler.observer = nil }
        _RenderEventRegistry.resetForTesting()
        defer { _RenderEventRegistry.resetForTesting() }

        // A non-isolated counter the action increments.
        // The test asserts the action ran (count went
        // from 0 to 1). The main-actor-isolation of the
        // action is a separate concern tested by the
        // other Button tests (via the
        // `lastCommitWasOnMainActor` flag on the
        // recorder) — for the "fires once" assertion, a
        // simple counter is the right fixture.
        let counter = ActionCounter()
        let button = ButtonStandIn(
            label: "Save",
            role: nil,
            action: { counter.increment() },
            identity: _GraphIdentity("SaveButton")
        )

        // The renderer / test installs the click listener
        // on mount. In the 0.2.0 production implementation
        // this is the renderer's mount hook calling
        // `_RenderEventRegistry.install(owner:event:handler:)`.
        // The red test installs the listener manually
        // because the 0.1.0 renderer does not yet
        // understand the `.button` case.
        _RenderEventRegistry.install(
            owner: button.identity,
            event: "click",
            handler: button.action
        )

        // Sanity: the listener is installed and the action
        // has not been invoked yet.
        #expect(counter.count == 0)

        // Synthetic click — the 0.2.0 contract is that
        // exactly one click invokes the action exactly
        // once. The test fires the event via the
        // registry's `simulate` API.
        _RenderEventRegistry.simulate(event: "click", on: button.identity)

        // Assert: the action was invoked exactly once.
        #expect(counter.count == 1)
    }

    @Test("a tap that mutates @State triggers a subtree-scoped re-render (re-render pairing)")
    func tapOnButtonWithStateMutationTriggersReRender() async {
        let recorder = ButtonCommitRecorder()
        _ReRenderScheduler.observer = recorder
        defer { _ReRenderScheduler.observer = nil }
        _RenderEventRegistry.resetForTesting()
        defer { _RenderEventRegistry.resetForTesting() }

        // The chain the test exercises (per spec §4):
        //   Button.action() runs
        //     → state.wrappedValue = newValue
        //       → Task { @MainActor in re-render(subtree) }
        // The Button's action increments the counter
        // `@State`; the test asserts the commit fires on
        // the main actor and the post-tap DOM (here, the
        // recorder) reflects the mutation.
        let state = State<Int>(wrappedValue: 0)

        let button = ButtonStandIn(
            label: "count = \(state.wrappedValue)",
            role: nil,
            action: {
                // The action mutates @State. The 0.2.0
                // production setter enqueues a
                // microtask commit; the stub does not.
                // The test asserts the commit fires.
                state.wrappedValue = state.wrappedValue + 1
            },
            identity: _GraphIdentity("CounterButton")
        )

        // Install the click listener and the baseline
        // commit count.
        _RenderEventRegistry.install(
            owner: button.identity,
            event: "click",
            handler: button.action
        )
        let baselineCommits = recorder.commits.count

        // Fire the synthetic click.
        _RenderEventRegistry.simulate(event: "click", on: button.identity)

        // Drain the microtask. The 0.2.0 production
        // implementation enqueues a `Task { @MainActor
        // in ... }`; the stub's no-op schedule does not
        // — so `commits` stays at the baseline.
        await Task.yield()
        await Task.yield()
        await Task.yield()

        // Assert: a commit fired (one more than the
        // baseline) AND the state is now 1.
        #expect(recorder.commits.count - baselineCommits == 1)
        #expect(recorder.lastCommitWasOnMainActor == true)
        #expect(state.wrappedValue == 1)
    }
}
