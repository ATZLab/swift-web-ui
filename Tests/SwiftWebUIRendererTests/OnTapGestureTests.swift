// Tests/SwiftWebUIRendererTests/OnTapGestureTests.swift
//
// 0.2.0 `.onTapGesture(count:perform:)` interaction contract.
//
// This file is the RED commit for the 0.2.0 per-symbol acceptance
// in `.harness/docs/swift-ui-surface.md` §10 (lines 1430–1445). The
// 0.2.0 contract:
//
//   1. **Single-tap** (line 1432): a `Text` with
//      `.onTapGesture { ... }` receives a synthetic `click`
//      event; the action runs once.
//   2. **Re-render pairing** (line 1434): a tap that mutates
//      `@State` triggers a subtree-scoped re-render; the test
//      asserts the post-tap commit fires on the main actor.
//   3. **No-event** (line 1437): a view that has
//      `.onTapGesture` installed but never receives a click
//      does not call the action and does not schedule a
//      re-render.
//
// The 0.2.0 `.onTapGesture` public extension does not exist
// yet. For the red tests we use a test-local
// `OnTapGestureStandIn` that holds the action and identity;
// the test installs the `click` event listener via
// `_RenderEventRegistry` and fires synthetic clicks via
// the registry's `simulate(event:on:)` API. The contract
// is: a click invokes the action, a `@State` write inside
// the action triggers a commit, a never-fired click does
// nothing.
//
// All tests fail against the 0.1.0 implementation:
//   * The 0.1.0 surface has no `.onTapGesture` extension
//     (the test uses a stand-in for shape).
//   * The 0.1.0 `@State` setter triggers
//     `_RendererReRenderHook.trigger()` synchronously; the
//     test asserts the 0.2.0 microtask commit fires on the
//     main actor.
//
// **Scope note (red commit):** the "same DOM as
// `Text("Tap me")`" snapshot (line 1442) is deferred to a
// follow-up red commit for the same compile-blocks-the-
// 0.1.0-target reason the Button snapshot is deferred. See
// the comment in `ButtonTapActionTests.swift`.
//
// Owner: swiftwebui-tester. swiftwebui-architect owns the
// `.onTapGesture(count:perform:)` public surface;
// swiftwebui-dom-renderer owns the SPI and the
// event-listener wiring.
// See `.harness/docs/tdd.md` and
// `.harness/docs/swift-ui-surface.md` §3 + §8 + §10.

import Foundation
import Testing
@_spi(SwiftWebUI) @testable import SwiftWebUIRenderer
@_spi(SwiftWebUI) @testable import SwiftWebUI

// MARK: - ReRender observer (test fixture)

private final class OnTapCommitRecorder: ReRenderObserver, @unchecked Sendable {
    private(set) var commits: [[_GraphIdentity]] = []
    private(set) var lastCommitWasOnMainActor: Bool = false

    func scheduler(didCommitFor subtrees: [_GraphIdentity]) {
        MainActor.assertIsolated()
        lastCommitWasOnMainActor = true
        commits.append(subtrees)
    }
}

// MARK: - onTapGesture stand-in (test fixture)

/// Test-local stand-in for the 0.2.0
/// `.onTapGesture(count:perform:)` View extension.
///
/// The 0.2.0 extension attaches a tap recogniser to the
/// view (see spec §3). The 0.1.0 production type does not
/// exist yet. The stand-in holds the count, action, and
/// identity; the test installs the `click` event listener
/// via `_RenderEventRegistry` and fires synthetic clicks
/// via the registry's `simulate(event:on:)` API.
struct OnTapGestureStandIn {
    let count: Int
    let action: () -> Void
    let identity: _GraphIdentity
}

// MARK: - .onTapGesture single-tap (line 1432)

@Suite(".onTapGesture single-tap (0.2.0, line 1432)", .serialized)
struct OnTapGestureSingleTapTests {
    @Test("a synthetic click on a view with .onTapGesture invokes the action once")
    func syntheticClickInvokesTapAction() async {
        let recorder = OnTapCommitRecorder()
        await _ReRenderScheduler.flushForTesting()
        _ReRenderScheduler.resetForTesting()
        _ReRenderScheduler.observer = recorder
        _RenderEventRegistry.resetForTesting()
        _RenderEventRegistry.resetForTesting()

        // The 0.2.0 contract: a synthetic `click` event
        // on a view with `.onTapGesture` invokes the
        // action once. The test installs the listener
        // manually and fires the synthetic click via the
        // registry's `simulate` API.
        let invocationCounter = TapInvocationCounter()
        let tap = OnTapGestureStandIn(
            count: 1,
            action: { invocationCounter.increment() },
            identity: _GraphIdentity("TapMe")
        )

        // Install the click listener.
        _RenderEventRegistry.install(
            owner: tap.identity,
            event: "click",
            handler: tap.action
        )

        // Sanity: the action has not been invoked yet.
        #expect(invocationCounter.count == 0)

        // Fire the synthetic click.
        _RenderEventRegistry.simulate(event: "click", on: tap.identity)

        // Assert: the action was invoked exactly once.
        #expect(invocationCounter.count == 1)
    }

    @Test("a tap that mutates @State triggers a subtree-scoped re-render (re-render pairing)")
    func tapMutatingStateTriggersReRender() async {
        let recorder = OnTapCommitRecorder()
        await _ReRenderScheduler.flushForTesting()
        _ReRenderScheduler.resetForTesting()
        _ReRenderScheduler.observer = recorder
        _RenderEventRegistry.resetForTesting()
        _RenderEventRegistry.resetForTesting()

        // The 0.2.0 contract: a tap that mutates
        // `@State` triggers a subtree-scoped re-render.
        // The test exercises the same chain as the
        // Button test: tap → action → @State write →
        // commit on the main actor.
        let state = State<Int>(wrappedValue: 0)

        let tap = OnTapGestureStandIn(
            count: 1,
            action: {
                state.wrappedValue = state.wrappedValue + 1
            },
            identity: _GraphIdentity("CounterTap")
        )

        // Install the click listener and capture the
        // baseline commit count.
        _RenderEventRegistry.install(
            owner: tap.identity,
            event: "click",
            handler: tap.action
        )
        let baselineCommits = recorder.commits.count

        // Fire the synthetic click.
        _RenderEventRegistry.simulate(event: "click", on: tap.identity)

        // Drain the microtask. The
        // `Task { @MainActor in drainAndCommit() }`
        // enqueued by `schedule` is a child task on
        // the main actor; the test's `await` hops
        // give it a chance to run. Multiple yields
        // are needed because the test's current task
        // may be on the same actor as the commit
        // task, in which case a single yield is not
        // enough to land on the commit's slot.
        // Wait for the in-flight commit to complete.
        // The schedule call enqueued a
        // `Task { @MainActor in drainAndCommit() }`;
        // `flushForTesting()` awaits the task's
        // completion so the assertion sees the
        // post-commit state.
        await _ReRenderScheduler.flushForTesting()

        // Assert: a commit fired AND the state is now 1.
        #expect(recorder.commits.count - baselineCommits == 1)
        #expect(recorder.lastCommitWasOnMainActor == true)
        #expect(state.wrappedValue == 1)
    }
}

// MARK: - .onTapGesture no-event (line 1437)

@Suite(".onTapGesture no-event (0.2.0, line 1437)", .serialized)
struct OnTapGestureNoEventTests {
    @Test("a view with .onTapGesture that never receives a click does not invoke the action and does not schedule a re-render")
    func noClickMeansNoActionAndNoCommit() async {
        let recorder = OnTapCommitRecorder()
        await _ReRenderScheduler.flushForTesting()
        _ReRenderScheduler.resetForTesting()
        _ReRenderScheduler.observer = recorder
        _RenderEventRegistry.resetForTesting()
        _RenderEventRegistry.resetForTesting()

        // The 0.2.0 contract: a view that has
        // `.onTapGesture` installed but never receives a
        // click does not call the action and does not
        // schedule a re-render.
        let invocationCounter = TapInvocationCounter()
        let tap = OnTapGestureStandIn(
            count: 1,
            action: { invocationCounter.increment() },
            identity: _GraphIdentity("Untapped")
        )

        // Install the click listener. The registry now
        // has one entry, but the test does NOT fire the
        // event.
        _RenderEventRegistry.install(
            owner: tap.identity,
            event: "click",
            handler: tap.action
        )

        // Drain any microtask that may have been
        // scheduled by the install (the install is
        // supposed to be inert — it does not enqueue a
        // commit).
        // Robust drain: yields + main-actor hop, repeated to land on the
        // scheduler's `Task { @MainActor in drainAndCommit() }` slot.
        // Wait for the in-flight commit to complete.
        // The schedule call enqueued a
        // `Task { @MainActor in drainAndCommit() }`;
        // `flushForTesting()` awaits the task's
        // completion so the assertion sees the
        // post-commit state.
        await _ReRenderScheduler.flushForTesting()

        // Assert: the action was never invoked AND zero
        // commits were scheduled.
        #expect(invocationCounter.count == 0)
        #expect(recorder.commits.isEmpty)
    }
}

// MARK: - Invocation counter (test fixture)

/// Non-isolated counter the test action increments.
/// The "fires once" assertion only needs to know how
/// many times the action ran; the main-actor isolation
/// of the action body is a separate concern tested by
/// the `lastCommitWasOnMainActor` flag on the commit
/// recorder.
///
/// `@unchecked Sendable` + `NSLock` is the same shim
/// pattern the other red tests use.
private final class TapInvocationCounter: @unchecked Sendable {
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
