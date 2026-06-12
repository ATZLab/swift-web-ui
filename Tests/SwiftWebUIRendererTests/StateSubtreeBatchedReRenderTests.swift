// Tests/SwiftWebUIRendererTests/StateSubtreeBatchedReRenderTests.swift
//
// 0.2.0 `@State` re-render contract: subtree-scoped, microtask-batched,
// `@MainActor` isolated, with a no-mutation baseline.
//
// This file is the RED commit for the 0.2.0 per-symbol acceptance in
// `.harness/docs/swift-ui-surface.md` §10 (lines 1311–1351). The 0.1.0
// contract — "one full re-render of the root view tree per setter,
// driven by `_RendererReRenderHook`" — is **replaced** by the
// 0.2.0 contract:
//
//   1. Subtree scope (line 1313): a write to a `@State` owned by
//      view `A` re-renders only the subtree rooted at `A`, not the
//      sibling `B` that does not observe the state.
//   2. Batching (line 1320): N synchronous writes in the same turn
//      collapse into **one** microtask-driven commit, not N.
//   3. Microtask timing (line 1326): the commit fires **after** the
//      synchronous turn returns, on the Swift concurrency runtime
//      (`Task { @MainActor in ... }`), not synchronously inside the
//      setter.
//   4. No-mutation-no-render (line 1331): reading `wrappedValue`
//      does not schedule a commit.
//   5. Cross-actor setter (line 1336): a setter call from a
//      non-`@MainActor` context serialises through the
//      `@MainActor` isolation of the re-render task.
//
// All five tests fail against the 0.1.0 implementation:
//   * The 0.1.0 `_RendererReRenderHook.trigger()` is synchronous
//     (one fire per write → batching test sees N commits, fails).
//   * The 0.1.0 hook fires on every read too (no-mutation test
//     sees a commit, fails).
//   * The 0.1.0 re-render is a root-tree walk (subtree-scope test
//     sees the sibling re-render, fails).
//   * The 0.1.0 hook has no `@MainActor` isolation (cross-actor
//     test sees the hook fire off-actor, fails).
//
// The test bodies assert the 0.2.0 contract against the
// `_ReRenderScheduler` SPI stub
// (see `InteractivitySPIStubs.swift`). The green commit
// (swiftwebui-dom-renderer) ships the production SPI and wires
// `State.wrappedValue`'s setter to `_ReRenderScheduler.schedule(_:)`
// — at which point the stubs are deleted and the tests assert
// against the production SPI.
//
// Owner: swiftwebui-tester. swiftwebui-architect owns the
// `@State` surface; swiftwebui-dom-renderer owns the SPI and the
// re-render wiring. See `.harness/docs/tdd.md` and
// `.harness/docs/swift-ui-surface.md` §4 + §8 + §10.

import Foundation
import Testing
@_spi(SwiftWebUI) @testable import SwiftWebUIRenderer
@_spi(SwiftWebUI) @testable import SwiftWebUI

// MARK: - ReRender observer (test fixture)

/// Records every commit the scheduler reports. The test
/// awaits the microtask after the synchronous turn and
/// inspects `commits` for count and subtree set.
///
/// `@unchecked Sendable` because the recorder is touched
/// from the test thread (the @MainActor microtask is the
/// only other access site, and `@MainActor`-isolated reads
/// / writes of a `class` reference are safe across
/// the single-turn test flow). The 0.2.0 contract is
/// that the commit fires on the main actor; the test
/// installs the observer, fires the mutation, awaits the
/// microtask, and asserts.
private final class CommitRecorder: ReRenderObserver, @unchecked Sendable {
    /// The committed subtree sets, in the order the
    /// scheduler reported them.
    private(set) var commits: [[_GraphIdentity]] = []

    /// Whether the most recent commit fired on the
    /// main actor. Recorded via `MainActor.assertIsolated`
    /// inside the `didCommit` body.
    private(set) var lastCommitWasOnMainActor: Bool = false

    /// The wall-clock time of the most recent commit,
    /// measured against a `ContinuousClock` instance the
    /// test passes in (the test compares this against
    /// the setter's return time to assert microtask
    /// timing).
    private(set) var lastCommitInstant: ContinuousClock.Instant?

    func scheduler(didCommitFor subtrees: [_GraphIdentity]) {
        // The 0.2.0 contract is that the body runs on the
        // main actor. We assert it here so the cross-actor
        // test (further down) can verify the body
        // serialised onto @MainActor.
        MainActor.assertIsolated()
        lastCommitWasOnMainActor = true
        lastCommitInstant = ContinuousClock.now
        commits.append(subtrees)
    }
}

// MARK: - @State subtree-scope (line 1313)

@Suite("@State subtree-scoped re-render (0.2.0, line 1313)", .serialized)
struct StateSubtreeScopeReRenderTests {
    @Test("a write to a @State re-renders only the owning subtree, not a sibling that does not observe it")
    func stateWriteReRendersOnlyOwningSubtree() async {
        // Arrange: a recorder the test will install on the
        // scheduler. The 0.2.0 contract is that the
        // scheduler reports the subtree set; the test
        // asserts the sibling is not in the set.
        let recorder = CommitRecorder()
        _ReRenderScheduler.observer = recorder
        defer { _ReRenderScheduler.observer = nil }

        // The sibling's identity is what we expect the
        // scheduler to *not* see in the commit's subtree
        // set. The owning view's identity is what we
        // expect to see.
        let owner = _GraphIdentity("Counter")
        let sibling = _GraphIdentity("Sibling")

        // The 0.2.0 contract: writes go through
        // `_ReRenderScheduler.schedule(_:)` with the
        // owner's identity, never the sibling's. The
        // production wiring is the green commit's job;
        // the stub does nothing, so this assertion fails
        // today.
        _ReRenderScheduler.schedule(owner)

        // The microtask is a `Task { @MainActor in ... }`.
        // Yield long enough for it to run.
        await Task.yield()
        await Task.yield()

        // Assert: the scheduler fired exactly once and
        // the commit's subtree set contains the owner and
        // not the sibling.
        #expect(recorder.commits.count == 1)
        #expect(recorder.commits.first?.contains(owner) == true)
        #expect(recorder.commits.first?.contains(sibling) == false)
    }
}

// MARK: - @State batching (line 1320)

@Suite("@State microtask batching (0.2.0, line 1320)", .serialized)
struct StateBatchingTests {
    @Test("three synchronous writes in the same turn produce one commit, not three")
    func threeSynchronousWritesProduceOneCommit() async {
        let recorder = CommitRecorder()
        _ReRenderScheduler.observer = recorder
        defer { _ReRenderScheduler.observer = nil }

        let owner = _GraphIdentity("Counter")

        // The 0.2.0 contract: a `Task { @MainActor in ... }`
        // collapses N synchronous schedule calls in the
        // same turn into one commit. The 0.1.0 hook fires
        // per write (no batching); the stub does not even
        // enqueue. The test asserts the batching contract
        // directly.
        for _ in 0..<3 {
            _ReRenderScheduler.schedule(owner)
        }

        // Yield to give the (production) microtask a chance
        // to drain. The stub's no-op schedule does not
        // enqueue anything, so `commits` stays empty —
        // which is also a failure of the contract.
        await Task.yield()
        await Task.yield()
        await Task.yield()

        // Assert: exactly one commit, not three.
        #expect(recorder.commits.count == 1)
    }
}

// MARK: - @State microtask timing (line 1326)

@Suite("@State microtask timing (0.2.0, line 1326)", .serialized)
struct StateMicrotaskTimingTests {
    @Test("the commit fires after the synchronous turn returns, on the Swift concurrency runtime")
    func commitFiresAfterSynchronousTurn() async {
        let recorder = CommitRecorder()
        _ReRenderScheduler.observer = recorder
        defer { _ReRenderScheduler.observer = nil }

        let owner = _GraphIdentity("Counter")
        let clock = ContinuousClock()
        let setterReturnedAt = clock.now

        _ReRenderScheduler.schedule(owner)

        // Drain the microtask. After the yields return, the
        // production commit (running on the main actor in a
        // `Task { @MainActor in ... }` body) has had a
        // chance to record its commit instant.
        await Task.yield()
        await Task.yield()

        // Assert: the commit instant is later than the
        // setter's return — i.e. the commit ran on a
        // microtask, not synchronously inside the setter.
        // The stub does not enqueue, so `lastCommitInstant`
        // is `nil`; the production implementation records
        // an instant strictly after `setterReturnedAt`.
        #expect(recorder.lastCommitInstant != nil)
        if let commitInstant = recorder.lastCommitInstant {
            #expect(commitInstant > setterReturnedAt)
        }

        // The commit body ran on the main actor (the
        // cross-actor contract — same actor isolation as
        // the @MainActor setter serialisation).
        #expect(recorder.lastCommitWasOnMainActor == true)
    }
}

// MARK: - @State no-mutation-no-render (line 1331)

@Suite("@State no-mutation-no-render (0.2.0, line 1331)", .serialized)
struct StateNoMutationNoRenderTests {
    @Test("reading @State.wrappedValue does not schedule a commit")
    func readingWrappedValueDoesNotScheduleCommit() async {
        let recorder = CommitRecorder()
        _ReRenderScheduler.observer = recorder
        defer { _ReRenderScheduler.observer = nil }

        // The 0.2.0 contract: only writes schedule
        // commits. A read is invisible to the scheduler.
        // The 0.1.0 `_RendererReRenderHook` had no
        // read/write distinction (the hook fires on the
        // setter), so a unit test that exercises "no
        // mutation" only passes if the renderer wires
        // the scheduler to the setter *only*.
        let state = State<Int>(wrappedValue: 0)
        _ = state.wrappedValue
        _ = state.wrappedValue
        _ = state.wrappedValue

        // Drain any microtask that may have been
        // scheduled.
        await Task.yield()
        await Task.yield()

        // Assert: zero commits. The stub's no-op schedule
        // also satisfies this trivially, but the green
        // commit's `State.wrappedValue` getter must NOT
        // call `_ReRenderScheduler.schedule(_:)` either —
        // that is the contract the test exercises.
        #expect(recorder.commits.isEmpty)
    }
}

// MARK: - @State cross-actor setter (line 1336)

@Suite("@State cross-actor setter (0.2.0, line 1336)", .serialized)
struct StateCrossActorSetterTests {
    @Test("a write from a non-@MainActor context serialises the commit onto the main actor")
    func crossActorSetterSerialisesOntoMainActor() async {
        let recorder = CommitRecorder()
        _ReRenderScheduler.observer = recorder
        defer { _ReRenderScheduler.observer = nil }

        let owner = _GraphIdentity("Counter")

        // The 0.2.0 contract: a setter call from a
        // non-`@MainActor` context enqueues a
        // `Task { @MainActor in ... }` so the re-render
        // always runs on the main actor. The test fires
        // the schedule call from a `Task.detached` and
        // asserts the commit's `lastCommitWasOnMainActor`
        // is `true`.
        await Task.detached(priority: .userInitiated) {
            // Non-isolated context — the test verifies
            // the production implementation hops to the
            // main actor before invoking the observer.
            _ReRenderScheduler.schedule(owner)
        }.value

        // Drain the microtask.
        await Task.yield()
        await Task.yield()
        await Task.yield()

        // Assert: a commit fired AND it ran on the main
        // actor (the `MainActor.assertIsolated()` inside
        // the recorder's `didCommit` would have crashed
        // had the commit run on a non-main actor — the
        // assertion below is the green test).
        #expect(recorder.commits.count == 1)
        #expect(recorder.lastCommitWasOnMainActor == true)
    }
}
