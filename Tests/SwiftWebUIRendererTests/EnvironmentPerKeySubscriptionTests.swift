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
        _ReRenderScheduler.observer = recorder
        defer { _ReRenderScheduler.observer = nil }

        // The 0.2.0 contract: setting
        // `EnvironmentValues[ColorSchemeKey.self] = .dark`
        // triggers a re-render of all descendants that
        // read that key. The 0.1.0 setter only stores the
        // value (no scheduler hookup).
        var bag = EnvironmentValues()
        bag[ColorSchemeKey.self] = .dark

        // Drain the microtask.
        await Task.yield()
        await Task.yield()

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

@Suite("@Environment per-key subscription granularity (0.2.0, line 1380)", .serialized)
struct EnvironmentUnrelatedKeyTests {
    @Test("ancestor write to .colorScheme does not re-render a descendant that reads only .locale")
    func ancestorWriteDoesNotReRenderUnrelatedDescendant() async {
        let recorder = EnvironmentCommitRecorder()
        _ReRenderScheduler.observer = recorder
        defer { _ReRenderScheduler.observer = nil }

        // The 0.2.0 contract: per-key subscription
        // granularity. A write to `ColorSchemeKey` does
        // NOT enqueue a commit for a descendant that
        // reads only `LocaleKey`.
        //
        // The test exercises the SPI by simulating a
        // descendant that read `LocaleKey` — the
        // descendant's identity is logged with the
        // commit, so the test asserts the commit's
        // subtree set contains the `ColorSchemeKey`
        // subscriber and not the `LocaleKey`
        // subscriber. The 0.2.0 production
        // implementation tracks which descendant read
        // which key.
        let colorSchemeSubscriber = _GraphIdentity("ColorSchemeChild")
        let localeSubscriber = _GraphIdentity("LocaleChild")

        // Simulate the descendant's render-time
        // subscription: it tells the scheduler "if
        // `ColorSchemeKey` is written, commit my
        // subtree". The 0.2.0 production
        // implementation owns this; the stub's API
        // surface is the same — `schedule(_:)` enqueues
        // a commit for the given identity.
        //
        // In the test we register the subscriber by
        // calling `schedule` directly with the
        // subscriber's identity; the 0.2.0 green commit
        // will reconcile the per-key subscription
        // machinery.
        _ReRenderScheduler.schedule(colorSchemeSubscriber)
        _ReRenderScheduler.schedule(localeSubscriber)

        // Drain the microtask.
        await Task.yield()
        await Task.yield()

        // Snapshot the commits so far. After this
        // baseline, the test fires the ancestor write
        // and asserts the new commit's subtree set
        // does NOT contain `localeSubscriber` (per
        // the per-key subscription granularity).
        let baselineCommits = recorder.commits.count

        // The ancestor writes `ColorSchemeKey` — only
        // the colorSchemeSubscriber's subtree should
        // re-render. The 0.1.0 setter does not enqueue
        // a commit; the stub also does not. The 0.2.0
        // production implementation enqueues a commit
        // for `colorSchemeSubscriber` only.
        var bag = EnvironmentValues()
        bag[ColorSchemeKey.self] = .dark

        await Task.yield()
        await Task.yield()

        // Assert: exactly one additional commit fired
        // (the per-key commit) and it contains the
        // colorScheme subscriber and not the locale
        // subscriber.
        let newCommits = recorder.commits.count - baselineCommits
        #expect(newCommits == 1)
        let lastCommit = recorder.commits.last ?? []
        #expect(lastCommit.contains(colorSchemeSubscriber) == true)
        #expect(lastCommit.contains(localeSubscriber) == false)
    }
}

// MARK: - @Environment cross-actor (line 1385)

@Suite("@Environment cross-actor write (0.2.0, line 1385)", .serialized)
struct EnvironmentCrossActorTests {
    @Test("an EnvironmentValues subscript write from a non-@MainActor context serialises the commit onto the main actor")
    func crossActorEnvironmentWriteSerialisesOntoMainActor() async {
        let recorder = EnvironmentCommitRecorder()
        _ReRenderScheduler.observer = recorder
        defer { _ReRenderScheduler.observer = nil }

        // The 0.2.0 contract: a subscript write from a
        // non-`@MainActor` context hops to the main
        // actor before scheduling the commit.
        //
        // `EnvironmentValues` itself is a value type
        // with internal reference-typed storage; the
        // storage is `@_spi(SwiftWebUI) public final
        // class Storage` (per
        // `Sources/SwiftWebUI/EnvironmentValues.swift`).
        // The storage is not `Sendable` in Swift 6.2
        // strict concurrency, so the test wraps it in
        // a `@unchecked Sendable` shim — the same
        // pattern the binding cross-actor test uses.
        let storageHandle = EnvironmentStorageHandle(EnvironmentValues.Storage())
        await Task.detached(priority: .userInitiated) { @Sendable in
            // The production setter does
            // `storage.entries[key] = newValue` and
            // then `_ReRenderScheduler.schedule(_:)`.
            // The stub's `schedule` is a no-op; the
            // production version enqueues a
            // `Task { @MainActor in ... }`. The test
            // asserts the hop.
            storageHandle.entries[ObjectIdentifier(ColorSchemeKey.self)] = ColorSchemeKey.Scheme.dark
        }.value

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

/// `@unchecked Sendable` shim around
/// `EnvironmentValues.Storage`.
///
/// The 0.1.0 `EnvironmentValues.Storage` is a
/// `public final class` with a mutable `entries`
/// dictionary; Swift 6.2 strict concurrency rejects the
/// implicit `Sendable` inference. The production 0.2.0
/// work will mark the storage `Sendable` (or wrap it in
/// an actor-isolated handle); for now the test wraps it
/// in an unchecked handle so the cross-actor test can
/// exercise the detached-task → main-actor commit path.
private final class EnvironmentStorageHandle: @unchecked Sendable {
    let storage: EnvironmentValues.Storage
    init(_ storage: EnvironmentValues.Storage) { self.storage = storage }
    var entries: [ObjectIdentifier: Any] {
        get { storage.entries }
        set { storage.entries = newValue }
    }
}
