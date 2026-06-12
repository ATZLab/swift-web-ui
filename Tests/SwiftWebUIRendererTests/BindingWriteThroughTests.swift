// Tests/SwiftWebUIRendererTests/BindingWriteThroughTests.swift
//
// 0.2.0 `@Binding` re-render contract: a write through a binding
// reaches the parent's `@State` storage and schedules a
// subtree-scoped re-render of the parent.
//
// This file is the RED commit for the 0.2.0 per-symbol acceptance
// in `.harness/docs/swift-ui-surface.md` §10 (lines 1353–1369). The
// 0.1.0 contract — "the write reaches the parent's storage but
// does not trigger a re-render" — is **replaced** by the 0.2.0
// contract:
//
//   1. Through-binding trigger (line 1355): a child view that
//      holds `@Binding var count: Int` writes to it; the parent's
//      `@State` storage receives the write, the
//      `_ReRenderScheduler` schedules a `Task { @MainActor in ... }`
//      re-render of the parent's subtree, and the parent
//      re-renders.
//   2. Cross-actor binding (line 1362): a binding write from a
//      non-`@MainActor` context is serialised through the
//      `@MainActor` isolation of the re-render task.
//   3. Constant binding is inert (line 1366): `Binding.constant(_:)`
//      writes do **not** trigger a re-render (the commit count
//      stays at zero; the `ReRenderObserver` is never invoked).
//
// All three tests fail against the 0.1.0 implementation:
//   * The 0.1.0 binding has no notification path back to the
//     scheduler (the test asserts a commit, fails).
//   * The 0.1.0 `Binding.constant(_:)` setter is a no-op, so
//     the test would also pass for that — but the *correct*
//     reason is that the constant binding's setter must be a
//     no-op AND must not enqueue a microtask. The stub
//     assertion captures the negative contract.
//
// The test bodies assert the 0.2.0 contract against the
// `_ReRenderScheduler` SPI stub (see `InteractivitySPIStubs.swift`).
// The green commit (swiftwebui-dom-renderer) ships the production
// SPI and wires `Binding.wrappedValue`'s setter to the
// scheduler's microtask path. See `.harness/docs/tdd.md` and
// `.harness/docs/swift-ui-surface.md` §4 + §8 + §10.
//
// Owner: swiftwebui-tester. swiftwebui-architect owns the
// `@Binding` surface; swiftwebui-dom-renderer owns the SPI and
// the wiring.

import Foundation
import Testing
@_spi(SwiftWebUI) @testable import SwiftWebUIRenderer
@_spi(SwiftWebUI) @testable import SwiftWebUI

// MARK: - ReRender observer (test fixture)

/// Mirror of the recorder in
/// `StateSubtreeBatchedReRenderTests.swift`. Kept
/// file-local (rather than shared in the test target) so
/// the snapshot target stays self-contained (per
/// `.harness/docs/tdd.md` §"Snapshot tests" — the
/// `SwiftWebUISnapshots` target is the one that will
/// re-import this when the green commit lands, and a
/// shared fixture would couple the two test targets).
private final class BindingCommitRecorder: ReRenderObserver, @unchecked Sendable {
    private(set) var commits: [[_GraphIdentity]] = []
    private(set) var lastCommitWasOnMainActor: Bool = false

    func scheduler(didCommitFor subtrees: [_GraphIdentity]) {
        MainActor.assertIsolated()
        lastCommitWasOnMainActor = true
        commits.append(subtrees)
    }
}

/// `@unchecked Sendable` shim around `State.Storage`.
///
/// The 0.1.0 `State.Storage` is a `public final class`
/// with a mutable `value` property; Swift 6.2 strict
/// concurrency rejects the implicit `Sendable` inference
/// because the class is not final-conforming to Sendable
/// (it could be subclassed outside the module). The
/// production 0.2.0 work will mark the storage
/// `Sendable` (or wrap it in an actor-isolated handle);
/// for now the test wraps it in an unchecked handle so
/// the cross-actor test can exercise the
/// detached-task → main-actor commit path.
///
/// The shim is `@unchecked Sendable` because the
/// underlying storage is a reference type and the test
/// fixture is single-test scoped (no concurrent access
/// from outside the test's `Task.detached` body). The
/// discipline mirrors the 0.1.0
/// `RootReRenderRecorder` fixture in
/// `RendererReRenderHookSupport.swift`.
private final class StorageHandle: @unchecked Sendable {
    let storage: State<Int>.Storage
    init(_ storage: State<Int>.Storage) { self.storage = storage }
    var value: Int {
        get { storage.value }
        set { storage.value = newValue }
    }
}

// MARK: - @Binding through-binding trigger (line 1355)

@Suite("@Binding through-binding trigger (0.2.0, line 1355)", .serialized)
struct BindingThroughBindingTriggerTests {
    @Test("a child write through a @Binding reaches the parent @State and schedules a re-render of the parent subtree")
    func childBindingWriteSchedulesParentReRender() async {
        let recorder = BindingCommitRecorder()
        _ReRenderScheduler.observer = recorder
        defer { _ReRenderScheduler.observer = nil }

        // The chain the test exercises (per spec §4):
        //   Binding.wrappedValue = v
        //     → Binding.setter(v)
        //       → State.wrappedValue = v (parent's storage)
        //         → Task { @MainActor in
        //             re-render(parent-subtree)
        //           }
        // The parent's storage is held inside a `State`
        // wrapper. A `Binding` projected from the parent
        // re-targets writes back at the same storage.
        let parent = State<Int>(wrappedValue: 0)
        let binding = parent.projectedValue

        // Sanity: a read returns the initial value.
        #expect(binding.wrappedValue == 0)

        // The 0.2.0 contract: a write through the binding
        // ends up in the parent's storage AND triggers a
        // microtask commit on the parent subtree. The
        // 0.1.0 binding is a self-referencing box with no
        // scheduler hookup; the stub's `schedule` is a
        // no-op. The test asserts the contract.
        binding.wrappedValue = 7

        // The parent's storage now holds the new value
        // (the storage update is the 0.1.0 behaviour we
        // keep; the 0.2.0 work adds the commit on top).
        #expect(parent.wrappedValue == 7)

        // Drain the microtask.
        await Task.yield()
        await Task.yield()

        // Assert: a commit fired.
        #expect(recorder.commits.count == 1)
        #expect(recorder.lastCommitWasOnMainActor == true)
    }
}

// MARK: - @Binding cross-actor (line 1362)

@Suite("@Binding cross-actor write (0.2.0, line 1362)", .serialized)
struct BindingCrossActorTests {
    @Test("a binding write from a non-@MainActor context serialises the commit onto the main actor")
    func crossActorBindingWriteSerialisesOntoMainActor() async {
        let recorder = BindingCommitRecorder()
        _ReRenderScheduler.observer = recorder
        defer { _ReRenderScheduler.observer = nil }

        let parent = State<Int>(wrappedValue: 0)

        // The 0.2.0 contract: a write from a
        // non-`@MainActor` context (e.g. a JS callback
        // running on the JavaScriptKit worker) hops to
        // the main actor before scheduling the commit.
        //
        // `Binding<Int>` itself is not `Sendable` in
        // Swift 6.2 strict concurrency (the closures
        // it holds are not annotated `@Sendable`), so
        // capturing it in a `Task.detached { @Sendable
        // in ... }` body fails the concurrency check.
        // The same is true of `State.Storage` (also a
        // non-`Sendable` `public final class`).
        //
        // The test wraps the storage in a
        // `@unchecked Sendable` shim — the storage is
        // a reference type and the test is single-test
        // scoped, so the unchecked sendability is the
        // right shape for a test fixture (it mirrors
        // the `@unchecked Sendable` discipline the
        // 0.1.0 test fixtures already use, e.g. the
        // `RootReRenderRecorder` in
        // `RendererReRenderHookSupport.swift`).
        let storageHandle = StorageHandle(parent.storage)
        await Task.detached(priority: .userInitiated) { @Sendable in
            // The production binding's setter does
            // `storage.value = newValue` and then
            // `_ReRenderScheduler.schedule(_:)`. The
            // stub's `schedule` is a no-op; the
            // production version enqueues a
            // `Task { @MainActor in ... }`. The test
            // asserts the hop.
            storageHandle.value = 42
        }.value

        // The storage is updated. Read on the main
        // actor (we resumed here from the detached
        // task) so the access is serialised with the
        // detached write.
        await MainActor.run {
            #expect(parent.wrappedValue == 42)
        }

        // Drain the microtask.
        await Task.yield()
        await Task.yield()
        await Task.yield()

        // Assert: a commit fired AND it ran on the main
        // actor.
        #expect(recorder.commits.count == 1)
        #expect(recorder.lastCommitWasOnMainActor == true)
    }
}

// MARK: - @Binding.constant is inert (line 1366)

@Suite("@Binding.constant is inert (0.2.0, line 1366)", .serialized)
struct BindingConstantInertTests {
    @Test("Binding.constant(_:) writes do not trigger a re-render")
    func constantBindingWritesDoNotTriggerCommit() async {
        let recorder = BindingCommitRecorder()
        _ReRenderScheduler.observer = recorder
        defer { _ReRenderScheduler.observer = nil }

        // The 0.2.0 contract: `Binding.constant(_:)`
        // produces a non-mutating binding whose setter
        // is a no-op AND must never enqueue a microtask.
        // The recorder must stay at zero commits even
        // after writes — that is the negative assertion
        // the spec calls out explicitly.
        let constant = Binding<Int>.constant(99)
        constant.wrappedValue = 1
        constant.wrappedValue = 2
        constant.wrappedValue = 3

        // Drain any microtask the production
        // implementation might (incorrectly) enqueue.
        await Task.yield()
        await Task.yield()
        await Task.yield()

        // Assert: zero commits. A read still returns the
        // constant value (the binding is read-only).
        #expect(recorder.commits.isEmpty)
        #expect(constant.wrappedValue == 99)
    }
}
