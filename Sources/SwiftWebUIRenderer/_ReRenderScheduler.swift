// Sources/SwiftWebUIRenderer/_ReRenderScheduler.swift
//
// The renderer's re-render notification seam (v0.2.0).
//
// In 0.1.0 the renderer's notification path was a
// thread-local hook (`_RendererReRenderHook`): the
// `@State` setter called the hook synchronously, exactly
// once per write, on the calling thread. In 0.2.0 the path
// is a **subtree-scoped, microtask-batched** scheduler
// pinned to `Task { @MainActor in ... }` on the Swift
// concurrency runtime (per the architect's
// `.harness/docs/swift-ui-surface.md` §4 + §8 and the
// owner decision documented in §11 self-critique item
// (1)):
//
//   * `schedule(_:)` records the subtree identity in a
//     pending set. N synchronous schedule calls in the
//     same turn collapse into a **single** commit.
//   * The commit is enqueued as a
//     `Task { @MainActor in ... }`. The body of the task
//     runs on the main actor, drains the pending set, and
//     invokes the installed `ReRenderObserver` once with
//     the dedup'd subtree list.
//   * The actor isolation is the contract — a setter
//     call from any actor (e.g. a `Task.detached { ... }`
//     or a JavaScriptKit callback) lands in the same
//     `@MainActor`-isolated commit body. The scheduler
//     serialises through the main actor regardless of
//     where `schedule` was called from.
//
// The slot is a single global because 0.2.0 is
// single-threaded on the host (and the wasm32 target is
// JS-thread-equivalent). The 0.3.0 work that introduces
// worker-thread re-rendering will replace the slot with a
// `Synchronization.Mutex`; the API surface stays the same.
//
// Owner: swiftwebui-dom-renderer. Architect owns the
// `@State` / `@Binding` / `@Environment` public surface;
// the renderer owns this seam.

import Foundation

/// The renderer's re-render notification seam (v0.2.0).
///
/// `@State`, `@Binding`, and `EnvironmentValues` setters
/// call `_ReRenderScheduler.schedule(_:)` to enqueue a
/// subtree-scoped re-render. The scheduler collapses
/// synchronous writes in the same turn into a single
/// `Task { @MainActor in ... }` commit and invokes the
/// installed `ReRenderObserver` once with the dedup'd
/// subtree set.
///
/// ## Overview
///
/// The 0.2.0 contract (`.harness/docs/swift-ui-surface.md`
/// §4 + §8 + §10):
///
/// 1. **Subtree scope.** A write to a `@State` owned by
///    view `A` schedules a commit whose `subtrees` is
///    `{A, A.children}` and not `{root, root.subtree}`.
///    The identity is what the caller passes to
///    `schedule(_:)`; the scheduler does not look inside
///    the view tree.
/// 2. **Batching.** N synchronous schedule calls in the
///    same turn collapse into a single commit. The
///    pending-subtree set is dedup'd by
///    `_GraphIdentity` equality (label-based in 0.2.0,
///    see `_GraphIdentity.swift`).
/// 3. **Microtask primitive.** The commit is enqueued as
///    a `Task { @MainActor in ... }` on the Swift
///    concurrency runtime — **not** a
///    `DispatchQueue.main.async`, **not** a custom
///    microtask queue. The body runs on the main actor
///    regardless of the calling actor.
/// 4. **No read-side scheduling.** Reading
///    `@State.wrappedValue` does not schedule a commit.
///    Only writes do.
/// 5. **Test observer.** The renderer installs a
///    `ReRenderObserver` (the renderer's
///    commit-handling body). Tests install their own
///    observer (a `CommitRecorder`) to count commits
///    and assert the subtree set.
///
/// ## Deprecated 0.1.0 hook
///
/// The 0.1.0 `_RendererReRenderHook` is kept in
/// `RendererReRenderHook.swift` for the 0.1.0 → 0.2.0
/// transition (the `State.wrappedValue` setter calls
/// both for the duration of 0.2.0). The hook is
/// `@available(*, deprecated)` and will be removed in
/// 0.3.0.
@_spi(SwiftWebUI)
public enum _ReRenderScheduler {
    /// Serialises access to the scheduler's mutable
    /// state (`pending` set, `inFlight` flag, `observer`
    /// slot). All public methods take the lock around
    /// their state reads and writes.
    private static let lock = NSLock()

    /// The currently installed observer, or `nil` if
    /// none.
    ///
    /// Production code (the renderer) installs an
    /// observer at mount time. Tests install their own
    /// observer before triggering a mutation and assert
    /// the commit count / subtree set after the
    /// microtask has run.
    public static var observer: ReRenderObserver? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _observer
        }
        set {
            lock.lock()
            _observer = newValue
            lock.unlock()
        }
    }

    /// Backing storage for `observer`. The lock-protected
    /// computed property is the public API.
    private nonisolated(unsafe) static var _observer: ReRenderObserver?

    /// The dedup'd set of subtrees the next commit will
    /// re-render. Drained under the lock when the
    /// microtask fires.
    private nonisolated(unsafe) static var pending: Set<_GraphIdentity> = []

    /// Whether a microtask is currently in flight. The
    /// scheduler enqueues at most one task per "drain
    /// cycle"; new schedule calls during the cycle add
    /// to `pending` and the next enqueue is triggered by
    /// the cycle's tail (the task body, after it drains,
    /// re-checks `pending` and re-enqueues if anything
    /// landed in the window between the drain and the
    /// `inFlight` reset).
    private nonisolated(unsafe) static var inFlight: Bool = false

    /// The most recently enqueued drain `Task`. Tests
    /// `await` this to ensure the in-flight commit has
    /// completed before the test asserts. `nil` when no
    /// task is in flight.
    private nonisolated(unsafe) static var inFlightTask: Task<Void, Never>?

    /// Schedules a re-render of the subtree rooted at
    /// `subtree`.
    ///
    /// Multiple synchronous calls in the same turn
    /// collapse into a single commit (the `pending` set
    /// is dedup'd by `_GraphIdentity` equality). The
    /// commit fires on the main actor, in a
    /// `Task { @MainActor in ... }` body, after the
    /// synchronous turn returns.
    ///
    /// The observer is invoked once per drain with the
    /// dedup'd subtree set. If no observer is installed
    /// the commit is still enqueued (a future install
    /// will not see it) — the test fixture installs an
    /// observer **before** the schedule call, the
    /// production renderer installs one at mount.
    public static func schedule(_ subtree: _GraphIdentity) {
        lock.lock()
        pending.insert(subtree)
        if inFlightTask == nil {
            inFlight = true
            let task = Task { @MainActor in
                drainAndCommit()
            }
            inFlightTask = task
            lock.unlock()
        } else {
            lock.unlock()
        }
    }

    /// Resets the scheduler to its empty state. Tests
    /// call this in `setUp` (or via `defer`) to keep
    /// state from leaking into other tests.
    ///
    /// The 0.2.0 host matrix is single-threaded for
    /// `pending` and `inFlight`; the `Task { @MainActor
    /// in ... }` body the scheduler enqueues is
    /// `@MainActor`-isolated, and any task that lands
    /// after the reset will observe a clean state. The
    /// observer is reset to `nil` — tests that need an
    /// observer install it after the reset.
    public static func resetForTesting() {
        lock.lock()
        _observer = nil
        pending.removeAll()
        inFlight = false
        lock.unlock()
    }

    /// Awaits the in-flight commit to complete.
    ///
    /// The scheduler's commit body runs in a
    /// `Task { @MainActor in ... }`. `flushForTesting()`
    /// captures the current `inFlightTask` and `await`s
    /// its `value`, guaranteeing the commit has run
    /// before the test asserts. This is the
    /// **correct** drain helper; `drainForTesting` is a
    /// weaker helper that returns when the in-flight
    /// flag is clear (which can be earlier than
    /// observer-call completion on a busy scheduler).
    ///
    /// Tests call `await _ReRenderScheduler.flushForTesting()`
    /// **before** their assertions (so the assertion
    /// sees the post-commit state) and again at the
    /// end of the test body (so the next test's entry
    /// sees a clean scheduler).
    public static func flushForTesting() async {
        // Capture the task under the lock, then await
        // it outside the lock. The await may take a
        // long time (the task hops to the main actor
        // and back); doing it outside the lock avoids
        // blocking other scheduler calls.
        let task: Task<Void, Never>? = {
            lock.lock()
            defer { lock.unlock() }
            return inFlightTask
        }()
        if let task {
            await task.value
        }
    }

    /// Awaits any in-flight commit to drain.
    ///
    /// The scheduler's commit body runs in a
    /// `Task { @MainActor in ... }`; the test fixture
    /// `await Task.yield()`s until the task has had a
    /// chance to run. `drainForTesting()` is the
    /// **weaker** helper (returns on the in-flight
    /// flag clearing) and is kept for tests that need
    /// a non-blocking drain. New code should prefer
    /// `flushForTesting()`.
    public static func drainForTesting() async {
        for _ in 0..<16 {
            let hasInFlight: Bool = {
                lock.lock()
                defer { lock.unlock() }
                return inFlight || !pending.isEmpty || inFlightTask != nil
            }()
            if !hasInFlight { return }
            await Task.yield()
        }
    }

    /// Drains the pending set, fires the observer, and
    /// re-enqueues if new schedule calls landed during
    /// the drain.
    ///
    /// Runs on the main actor (the `Task` body is
    /// `@MainActor`-isolated). The test fixtures
    /// `MainActor.assertIsolated()` inside their
    /// observer body to assert the isolation; the
    /// production observer does the same implicitly
    /// because it is `@MainActor`-isolated itself.
    @MainActor
    private static func drainAndCommit() {
        // Drain the pending set under the lock so a
        // concurrent `schedule` call cannot enqueue
        // between our snapshot and the observer call.
        lock.lock()
        let drained = Array(pending)
        pending.removeAll()
        // We will re-enqueue below if new writes landed
        // while the observer was running. Reset `inFlight`
        // first so the re-enqueue can flip it back on
        // atomically.
        inFlight = false
        let needReEnqueue = !pending.isEmpty
        if needReEnqueue {
            // The re-enqueue flag must be set before
            // the observer runs, otherwise a schedule
            // call between the drain and the observer
            // would see `inFlight == false` and enqueue
            // a second task — fine semantically, but we
            // want exactly one task per drain cycle.
            inFlight = true
        }
        let observer = _observer
        lock.unlock()

        // Fire the observer outside the lock so a
        // observer that calls back into the scheduler
        // (e.g. a renderer that triggers a further
        // re-render in response to a commit) does not
        // deadlock.
        observer?.scheduler(didCommitFor: drained)

        // If new schedule calls landed while the
        // observer was running, re-enqueue. The set
        // may have grown during the unlock window;
        // re-check under the lock.
        if needReEnqueue {
            lock.lock()
            let stillPending = !pending.isEmpty
            if stillPending {
                let task = Task { @MainActor in
                    drainAndCommit()
                }
                inFlightTask = task
                lock.unlock()
            } else {
                // The schedule that flipped our
                // re-enqueue flag has been drained by
                // another cycle; reset our flag so
                // future schedules start a fresh
                // cycle.
                inFlight = false
                inFlightTask = nil
                lock.unlock()
            }
        } else {
            // No re-enqueue needed. Clear `inFlightTask`
            // so the next `schedule` call starts a
            // fresh cycle and `flushForTesting()` can
            // observe completion.
            lock.lock()
            inFlightTask = nil
            lock.unlock()
        }
    }
}
