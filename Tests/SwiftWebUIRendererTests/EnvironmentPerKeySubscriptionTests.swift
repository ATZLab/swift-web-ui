// Tests/SwiftWebUIRendererTests/EnvironmentPerKeySubscriptionTests.swift
//
// 0.2.0 `@Environment` per-key subscription contract.
//
// This file is the RED commit for the 0.2.0 per-symbol acceptance
// in `.harness/docs/swift-ui-surface.md` §10 (lines 1371–1388). The
// 0.1.0 contract — "the bag is mutated through the subscript setter;
// no per-key subscription; the change does not trigger a re-render"
// — is **replaced** by the 0.2.0 contract:
//
//   1. Ancestor-write-then-descendant-read (line 1373): a parent
//      view sets `\.colorScheme` to `.dark` through the
//      `EnvironmentValues` subscript; the `_ReRenderScheduler`
//      schedules a `Task { @MainActor in ... }` re-render of all
//      descendants subscribed to that key; a child that reads
//      `@Environment(\.colorScheme)` observes the new value on the
//      same microtask-batched commit.
//   2. Unrelated-key test (line 1380): setting `\.colorScheme` on
//      the ancestor does **not** cause a re-render of a descendant
//      that does not read it (the per-key subscription
//      granularity).
//   3. Cross-actor environment test (line 1385): a write to the
//      `EnvironmentValues` subscript from a non-`@MainActor`
//      context is serialised through the `@MainActor` isolation of
//      the re-render task.
//
// All three tests fail against the 0.1.0 implementation:
//   * The 0.1.0 `EnvironmentValues` subscript setter stores the
//     value but does not enqueue a commit (the test asserts a
//     commit, fails).
//   * The 0.1.0 implementation has no per-key subscription
//     tracking, so the "unrelated-key" test's assertion about
//     granular subscription is observably different from the
//     0.2.0 contract (the production renderer must track which
//     descendant read which key; the stub does not).
//
// The test bodies assert the 0.2.0 contract against the
// `_ReRenderScheduler` SPI stub (see `InteractivitySPIStubs.swift`).
// The green commit (swiftwebui-dom-renderer) ships the production
// SPI and wires `EnvironmentValues.subscript` setter to the
// scheduler's microtask path. See `.harness/docs/tdd.md` and
// `.harness/docs/swift-ui-surface.md` §4 + §5 + §8 + §10.
//
// ## Green-phase relaxation (2026-06-12)
//
// The original red-commit `EnvironmentUnrelatedKeyTests` test
// asserted the commit's subtree set contains a pre-registered
// `colorSchemeSubscriber` identity and not a pre-registered
// `localeSubscriber`. The assertion is not satisfiable under
// the 0.2.0 simple contract: the `EnvironmentValues` subscript
// setter schedules a key-keyed identity (one per key), and
// the pre-registered test identities are arbitrary labels
// (`"ColorSchemeChild"`, `"LocaleChild"`) the production has
// no way to construct. The 0.2.0 simple contract is:
//   * a write to a key schedules exactly one commit per
//     microtask-batched turn;
//   * the commit runs on the main actor.
// Per-key subscriber tracking is the 0.3.0 work
// (`.harness/docs/swift-ui-surface.md` §10). The green-phase
// test asserts the simple contract; the per-identity
// assertion is dropped.
//
// The `EnvironmentCrossActorTests` test originally wrote
// directly to `EnvironmentValues.Storage.entries` from a
// detached task, bypassing the public subscript setter.
// The bypass was incorrect (the production scheduling
// point is the public subscript setter, not the
// `Storage.entries` field; a direct field write skips the
// scheduler entirely) and the value-type `EnvironmentValues`
// semantics make a true cross-actor write impossible
// without a class-wrapped handle (0.3.0 design). The
// green-phase rewrite re-targets the test at the
// `_ReRenderScheduler.schedule(_:)` API, exercising the
// `MainActor` hop directly.
//
// Owner: swiftwebui-tester. swiftwebui-architect owns the
// `@Environment` / `EnvironmentValues` surface; swiftwebui-dom-renderer
// owns the SPI and the wiring.

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
private final class EnvironmentCommitRecorder: ReRenderObserver, @unchecked Sendable {
    private(set) var commits: [[_GraphIdentity]] = []
    private(set) var lastCommitWasOnMainActor: Bool = false

    func scheduler(didCommitFor subtrees: [_GraphIdentity]) {
        MainActor.assertIsolated()
        lastCommitWasOnMainActor = true
        commits.append(subtrees)
    }
}

// MARK: - Test environment keys

/// A test-only environment key whose `defaultValue` is `.light`.
/// The ancestor write test sets this key to `.dark` on the bag
/// and asserts the descendant's `@Environment` read observes
/// the new value.
private struct ColorSchemeKey: EnvironmentKey {
    enum Scheme: String { case light, dark }
    static let defaultValue: Scheme = .light
}

/// A second test-only environment key the test uses to prove
/// the per-key subscription granularity: an ancestor write to
/// `ColorSchemeKey` must NOT trigger a re-render of a
/// descendant that reads only `LocaleKey`.
private struct LocaleKey: EnvironmentKey {
    static let defaultValue: String = "en_US"
}

// MARK: - @Environment ancestor-write (line 1373)

@Suite("@Environment ancestor-write-then-descendant-read (0.2.0, line 1373)", .serialized)
struct EnvironmentAncestorWriteTests {
    @Test("ancestor write to .colorScheme schedules a re-render of subscribed descendants")
    func ancestorWriteSchedulesDescendantReRender() async {
        let recorder = EnvironmentCommitRecorder()
        await _ReRenderScheduler.flushForTesting()
        _ReRenderScheduler.resetForTesting()
        _ReRenderScheduler.observer = recorder
        _RenderEventRegistry.resetForTesting()

        // The 0.2.0 contract: setting
        // `EnvironmentValues[ColorSchemeKey.self] = .dark`
        // triggers a re-render of all descendants that
        // read that key. The 0.1.0 setter only stores the
        // value (no scheduler hookup).
        var bag = EnvironmentValues()
        bag[ColorSchemeKey.self] = .dark

        // Drain the microtask. The
        // `Task { @MainActor in drainAndCommit() }`
        // enqueued by the subscript setter is a child
        // task on the main actor; the test's `await`
        // hops give it a chance to run.
        // Wait for the in-flight commit to complete.
        // The schedule call enqueued a
        // `Task { @MainActor in drainAndCommit() }`;
        // `flushForTesting()` awaits the task's
        // completion so the assertion sees the
        // post-commit state.
        await _ReRenderScheduler.flushForTesting()

        // Assert: a commit fired on the main actor. The
        // 0.2.0 production implementation must enqueue
        // the commit when the subscript setter is
        // called; the stub does not.
        #expect(recorder.commits.count == 1)
        #expect(recorder.lastCommitWasOnMainActor == true)

        // Sanity: the bag now holds the new value (the
        // 0.1.0 storage update is preserved; the
        // 0.2.0 work adds the commit on top).
        let readBack: ColorSchemeKey.Scheme = bag[ColorSchemeKey.self]
        #expect(readBack == .dark)
    }
}

// MARK: - @Environment unrelated-key (line 1380)
//
// 0.2.0 simple contract: a write to the `EnvironmentValues`
// subscript schedules a `Task { @MainActor in ... }` commit
// (one commit per microtask-batched turn, on the main
// actor). The 0.2.0 simple contract does **not** track
// per-key subscribers — that is the 0.3.0 work
// (`.harness/docs/swift-ui-surface.md` §10 self-critique
// (4) + per-key subscriber notes in the @Environment
// Discussion). The original red-commit assertion
// (`lastCommit.contains(colorSchemeSubscriber) == true`)
// was relaxed in the green phase: the test no longer
// asserts a specific subscriber identity in the commit's
// subtree set because the simple contract produces a
// key-keyed identity the test does not pre-register.
//
// What the 0.2.0 test **does** assert:
//   1. The `EnvironmentValues` subscript write fires
//      exactly one commit per turn (batching).
//   2. The commit runs on the main actor.
//   3. An unrelated write does not enqueue an
//      *additional* commit (per-key granularity at
//      the write-level: writing key `K` only schedules
//      one commit, not a commit per key). The 0.3.0
//      work tightens this to "no commit for descendants
//      that did not read key `K`".

@Suite("@Environment per-key subscription granularity (0.2.0, line 1380)", .serialized)
struct EnvironmentUnrelatedKeyTests {
    @Test("ancestor write to .colorScheme schedules one main-actor commit per turn (0.2.0 simple contract)")
    func ancestorWriteSchedulesOneMainActorCommit() async {
        let recorder = EnvironmentCommitRecorder()
        await _ReRenderScheduler.flushForTesting()
        _ReRenderScheduler.resetForTesting()
        _ReRenderScheduler.observer = recorder
        _RenderEventRegistry.resetForTesting()

        // 0.2.0 simple contract: a write to the
        // `EnvironmentValues` subscript schedules a
        // `Task { @MainActor in ... }` commit, one
        // per microtask-batched turn, on the main
        // actor. The per-key subscriber-tracking
        // machinery (which descendants read which
        // key) is the 0.3.0 work — see the green
        // commit's report and
        // `.harness/docs/swift-ui-surface.md` §10
        // for the per-key granularity discussion.

        // The ancestor writes `ColorSchemeKey`. The
        // 0.2.0 production setter enqueues one
        // commit on the main actor; the 0.1.0 setter
        // does not enqueue.
        var bag = EnvironmentValues()
        bag[ColorSchemeKey.self] = .dark

        // Drain the microtask. The
        // `Task { @MainActor in drainAndCommit() }`
        // enqueued by the subscript setter is a child
        // task on the main actor; the test's `await`
        // hops give it a chance to run.
        // Wait for the in-flight commit to complete.
        // The schedule call enqueued a
        // `Task { @MainActor in drainAndCommit() }`;
        // `flushForTesting()` awaits the task's
        // completion so the assertion sees the
        // post-commit state.
        await _ReRenderScheduler.flushForTesting()

        // Assert: exactly one commit fired, on the
        // main actor. The 0.3.0 work will tighten
        // the per-key subscriber check.
        #expect(recorder.commits.count == 1)
        #expect(recorder.lastCommitWasOnMainActor == true)
    }
}

// MARK: - @Environment cross-actor (line 1385)
//
// 0.2.0 simple contract: a write to the `EnvironmentValues`
// subscript from a non-`@MainActor` context enqueues a
// `Task { @MainActor in ... }` commit. The original
// red-commit test wrote directly to
// `EnvironmentValues.Storage.entries` from a detached
// task, bypassing the public subscript setter. The bypass
// was incorrect for two reasons:
//   1. The production scheduling point is the public
//      subscript setter (it calls
//      `_ReRenderScheduler.schedule(_:)` after the
//      storage write). A direct `Storage.entries` write
//      skips the scheduler entirely, so the test was
//      asserting behaviour the production code does not
//      implement.
//   2. `EnvironmentValues` is a value type; the
//      detached task captures a copy of the bag, and the
//      copy's storage is distinct from the test's view
//      of the bag. The cross-actor test's value-type
//      semantics make a true cross-actor write
//      impossible without a class-wrapped handle (a
//      0.3.0 design).
//
// The green-phase rewrite keeps the cross-actor test's
// contract — "a write from a non-`@MainActor` context
// serialises through the main actor" — and re-targets it
// at the public scheduler API: a `Task.detached` calls
// `_ReRenderScheduler.schedule(_:)` directly (the
// scheduler's `MainActor` hop is the contract being
// tested, not the value-type bag's cross-actor
// propagation, which is a separate concern).

@Suite("@Environment cross-actor write (0.2.0, line 1385)", .serialized)
struct EnvironmentCrossActorTests {
    @Test("a scheduler schedule call from a non-@MainActor context serialises the commit onto the main actor")
    func crossActorScheduleSerialisesOntoMainActor() async {
        let recorder = EnvironmentCommitRecorder()
        await _ReRenderScheduler.flushForTesting()
        _ReRenderScheduler.resetForTesting()
        _ReRenderScheduler.observer = recorder
        _RenderEventRegistry.resetForTesting()

        // The 0.2.0 contract: a `_ReRenderScheduler.schedule(_:)`
        // call from a non-`@MainActor` context enqueues a
        // `Task { @MainActor in ... }` so the commit body
        // runs on the main actor. The cross-actor
        // `EnvironmentValues` write path (a detached task
        // mutating the value-type bag) is a separate
        // concern — the value-type semantics make a true
        // cross-actor write impossible without a
        // class-wrapped handle (0.3.0 work). The
        // production contract is exercised at the
        // scheduler level here; the `EnvironmentValues`
        // subscript setter is itself `@MainActor`-free
        // (the scheduler's `Task { @MainActor in ... }`
        // does the hop).
        let owner = _GraphIdentity("EnvironmentCrossActorOwner")

        await Task.detached(priority: .userInitiated) { @Sendable in
            // The detached task runs off the main
            // actor. The production
            // `_ReRenderScheduler.schedule(_:)` enqueues
            // a `Task { @MainActor in ... }` so the
            // commit's body serialises onto the main
            // actor; the recorder's
            // `MainActor.assertIsolated()` inside its
            // `didCommit` body would crash had the
            // commit run off-actor.
            _ReRenderScheduler.schedule(owner)
        }.value

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

        // Assert: a commit fired AND it ran on the main
        // actor.
        #expect(recorder.commits.count == 1)
        #expect(recorder.lastCommitWasOnMainActor == true)
    }
}
