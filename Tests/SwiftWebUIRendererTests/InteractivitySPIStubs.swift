// Tests/SwiftWebUIRendererTests/InteractivitySPIStubs.swift
//
// 0.2.0 re-render SPI stubs used by the red tests in this target.
//
// The 0.2.0 spec (`.harness/docs/swift-ui-surface.md` §8) defines
// the following SPI:
//
//   - `@_spi(SwiftWebUI) public enum _ReRenderScheduler`
//       with `schedule(_:)` and a `commit(observer:)` entry point
//       for tests. The 0.2.0 implementation enqueues a
//       `Task { @MainActor in ... }` on the Swift concurrency
//       runtime; the body performs the re-render of the
//       scheduled subtree. The body is isolated to the
//       `@MainActor` and runs on the Swift concurrency runtime
//       (no `DispatchQueue.main.async`, no custom microtask
//       queue).
//
//   - `@_spi(SwiftWebUI) public protocol ReRenderObserver`
//       with `func scheduler(didCommitFor subtrees: [_GraphIdentity])`.
//       The observer is the only way a test can count commits
//       without depending on the renderer's internal queue.
//
//   - `@_spi(SwiftWebUI) public struct _GraphIdentity: Hashable`
//       the per-view identity the renderer uses to decide which
//       subtree a re-render applies to.
//
//   - `@_spi(SwiftWebUI) public enum _RenderEventRegistry`
//       the DOM event listener registry. `Button`, `TextField`,
//       and `.onTapGesture` install their listeners here.
//
// The dom-renderer rein ships the production versions of
// these types in `Sources/SwiftWebUIRenderer/`. Until that
// green commit lands, the red tests in this target compile
// against the *stubs* declared in this file. The shape
// matches the spec; the behaviour is intentionally
// not-yet-implemented (the stubs are no-ops so any red test
// that asserts commit counts / timing will fail at runtime
// against this stub, and the green commit replaces this file
// with a `delete` and the production SPI on the import side).
//
// Owner: swiftwebui-tester (this file is the test contract).
// The dom-renderer rein owns the production SPI. See
// `.harness/docs/tdd.md` for the red-then-green cycle and
// `.harness/docs/swift-ui-surface.md` §8 for the SPI table.

import Foundation

// MARK: - _ReRenderScheduler (SPI stub)

/// Stub for the production `@_spi(SwiftWebUI) public enum
/// _ReRenderScheduler`.
///
/// The 0.2.0 contract: synchronous writes collapse into a
/// single microtask-driven commit that runs on the main
/// actor. This stub does **not** implement the contract — it
/// is a stand-in so the red tests compile. The green commit
/// deletes this stub and the production SPI from
/// `Sources/SwiftWebUIRenderer/` takes over.
@_spi(SwiftWebUI)
public enum _ReRenderScheduler {
    /// Serialises access to the observer slot.
    ///
    /// swift-testing runs parallel tests across
    /// `non-.serialized` suites; even with `.serialized`,
    /// suites in the same test run execute concurrently
    /// unless the project's trait policy says otherwise.
    /// The 0.1.0 `_RendererReRenderHook` is a
    /// single-threaded slot; the 0.2.0 stub has to
    /// tolerate concurrent access because multiple
    /// red-test suites install observers.
    private static let observerLock = NSLock()

    /// The currently installed observer, or `nil` if no
    /// test has installed one.
    ///
    /// Production code never reads this slot. Tests install
    /// an observer before triggering a state mutation and
    /// assert the commit count / subtree set after the
    /// microtask has run.
    public static var observer: ReRenderObserver? {
        get {
            observerLock.lock()
            defer { observerLock.unlock() }
            return _observer
        }
        set {
            observerLock.lock()
            _observer = newValue
            observerLock.unlock()
        }
    }

    /// Backing storage for `observer`. The lock-protected
    /// computed property is the public API.
    private nonisolated(unsafe) static var _observer: ReRenderObserver?

    /// The default scheduler (no-op for the stub).
    ///
    /// The production version enqueues a
    /// `Task { @MainActor in ... }` that performs the
    /// re-render of the scheduled subtree.
    public static func schedule(_ subtree: _GraphIdentity) {
        // Intentionally a no-op in the stub. The red tests
        // assert the production behaviour: a microtask fires
        // after the synchronous turn, exactly once per
        // synchronous turn regardless of how many writes
        // happened in the turn. The stub failing the
        // assertions is the red signal.
        _ = subtree
    }
}

// MARK: - ReRenderObserver (SPI stub)

/// Stub for the production
/// `@_spi(SwiftWebUI) public protocol ReRenderObserver`.
///
/// Tests install a concrete observer before triggering a
/// state mutation, await the microtask, and assert the
/// observer received the expected commit count with the
/// expected subtree set.
@_spi(SwiftWebUI)
public protocol ReRenderObserver {
    /// Called by `_ReRenderScheduler` once per commit, on
    /// the main actor, in a `Task { @MainActor in ... }`
    /// body. `subtrees` is the set of view identities the
    /// commit re-renders.
    func scheduler(didCommitFor subtrees: [_GraphIdentity])
}

// MARK: - _GraphIdentity (SPI stub)

/// Stub for the production
/// `@_spi(SwiftWebUI) public struct _GraphIdentity: Hashable`.
///
/// The renderer uses the identity to decide which subtree
/// a re-render applies to. A write to a `@State` owned by
/// view `A` schedules a commit whose `subtrees` is
/// `{A, A.children}` and not `{root, root.subtree}`.
@_spi(SwiftWebUI)
public struct _GraphIdentity: Hashable {
    /// A debug-friendly label (e.g. the view type name).
    /// Not part of the equality contract — the identity is
    /// the runtime object's identity, not the label.
    public let label: String

    /// Creates an identity with the given label.
    public init(_ label: String) { self.label = label }
}

// MARK: - _RenderEventRegistry (SPI stub)

/// Stub for the production
/// `@_spi(SwiftWebUI) public enum _RenderEventRegistry`.
///
/// The 0.2.0 contract: `Button`, `TextField`, and
/// `.onTapGesture` install their DOM event listeners here.
/// The registry owns the `JSClosure` retain policy — the
/// listener is added on mount and removed on teardown.
///
/// The stub records install / remove calls so the
/// `install-on-mount / remove-on-teardown` test can assert
/// the listener lifecycle without a live DOM host. The
/// stub also accepts a `handler` closure on install so the
/// `tap-fires-action` / `keystroke-writes-binding` tests
/// can simulate a synthetic DOM event by calling
/// `simulate(event:on:owner:)`.
@_spi(SwiftWebUI)
public enum _RenderEventRegistry {
    /// A single listener entry: the identity of the view
    /// that owns it, the event name, a stable token the
    /// registry returns on install, and the handler the
    /// listener invokes on a matching DOM event.
    public struct Entry {
        public let owner: _GraphIdentity
        public let event: String
        public let token: Int
        public let handler: () -> Void

        public static func == (lhs: Entry, rhs: Entry) -> Bool {
            lhs.token == rhs.token
        }
    }

    /// The currently-installed listeners. The stub exposes
    /// the list for test assertions; the production
    /// implementation owns the `JSClosure` and never lets
    /// test code touch the listener.
    ///
    /// The 0.1.0 hook is single-threaded; the 0.2.0 stub
    /// has to tolerate concurrent access because multiple
    /// red-test suites install listeners in parallel
    /// (the `Button`, `TextField`, and `onTapGesture`
    /// suites all install click / input listeners).
    /// Reads / writes are serialised through
    /// `registryLock`.
    public static var installed: [Entry] {
        get {
            registryLock.lock()
            defer { registryLock.unlock() }
            return _installed
        }
        set {
            registryLock.lock()
            _installed = newValue
            registryLock.unlock()
        }
    }

    /// Backing storage for `installed`. The lock-protected
    /// computed property is the public API.
    private nonisolated(unsafe) static var _installed: [Entry] = []

    /// Serialises access to the registry's mutable state.
    private static let registryLock = NSLock()

    /// Resets the registry to its empty state. Tests call
    /// this in `setUp` to keep state out of other tests.
    public static func resetForTesting() {
        registryLock.lock()
        _installed.removeAll()
        nextToken = 0
        registryLock.unlock()
    }

    /// The next token to hand out on `install`.
    ///
    /// `nonisolated(unsafe)` — guarded by `registryLock`.
    private nonisolated(unsafe) static var nextToken: Int = 0

    /// Installs a listener for `event` owned by `owner`.
    /// Returns a token the caller uses to remove the
    /// listener.
    @discardableResult
    public static func install(owner: _GraphIdentity, event: String, handler: @escaping () -> Void) -> Int {
        registryLock.lock()
        let token = nextToken
        nextToken += 1
        _installed.append(Entry(owner: owner, event: event, token: token, handler: handler))
        registryLock.unlock()
        return token
    }

    /// Removes the listener with `token`. The test asserts
    /// the listener is gone after the parent re-renders
    /// without the child view.
    public static func remove(token: Int) {
        registryLock.lock()
        _installed.removeAll { $0.token == token }
        registryLock.unlock()
    }

    /// Simulates a synthetic DOM event of `event` on the
    /// listener owned by `owner`. The test fires a
    /// "synthetic click" or "synthetic input" via this
    /// method. The production implementation does not
    /// expose this — it is a test-only hook in the stub.
    public static func simulate(event: String, on owner: _GraphIdentity) {
        // Snapshot the matching handlers under the lock,
        // then invoke them outside the lock so a handler
        // that calls `simulate` recursively (or installs
        // / removes listeners) does not deadlock.
        registryLock.lock()
        let matching = _installed.filter { $0.event == event && $0.owner == owner }
        registryLock.unlock()
        for entry in matching {
            entry.handler()
        }
    }
}
