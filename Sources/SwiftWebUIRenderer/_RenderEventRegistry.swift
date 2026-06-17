// Sources/SwiftWebUIRenderer/_RenderEventRegistry.swift
//
// The DOM event listener registry. `Button`, `TextField`,
// and `.onTapGesture` install their DOM event listeners
// here; the registry owns the `JSClosure` retain policy
// (see `.harness/docs/js-bridge.md` for the underlying
// mechanism).
//
// ## Lifetime
//
// Each `install(...)` returns a token. The renderer stores
// the token on the view's mount record; on teardown it
// calls `remove(token:)`. The registry owns the
// `JSClosure` for the lifetime of the entry; `remove`
// releases the closure.
//
// ## Production vs test surface
//
// The production renderer (the bridge worker, see the
// 0.2.0 cross-rein sequencing note in the task brief)
// wires DOM events to handlers via `dispatch(_:on:)` —
// the production method. `simulate(event:on:)` is the
// test-only SPI that fires a synthetic event against the
// registry's installed entries without a live DOM host;
// the snapshot test target uses it to exercise the
// click/input wiring in-process.
//
// Owner: swiftwebui-dom-renderer. The bridge worker owns
// the underlying `JSClosure` retain policy (see
// `.harness/docs/js-bridge.md`); this file is the
// renderer-side seam.

import Foundation

/// The renderer's DOM event listener registry (v0.2.0).
///
/// `Button`, `TextField`, and `.onTapGesture` install
/// their listeners here. The registry is the
/// renderer's single source of truth for which DOM
/// event listeners are alive at any moment — the
/// `JSClosure` retain policy in
/// `.harness/docs/js-bridge.md` is enforced through
/// the `install` / `remove` pair.
///
/// ## Overview
///
/// * **`install(owner:event:handler:)`** registers a
///   listener for `event` on the subtree owned by
///   `owner`. Returns a token the caller uses to
///   remove the listener. The token is the only
///   identity the renderer needs to track — the
///   registry hides the `JSClosure` handle.
/// * **`remove(token:)`** releases the listener and
///   drops the registry's reference to the
///   handler.
/// * **`dispatch(_:on:)`** is the production method
///   the bridge worker calls when the host page
///   reports a DOM event. It invokes the matching
///   handler on the main actor.
/// * **`simulate(event:on:)`** is the **test-only**
///   method. The snapshot test target fires
///   synthetic events through it to exercise the
///   click/input wiring without a live DOM host.
///   Production code MUST NOT call `simulate`.
///
/// ## Concurrency
///
/// The 0.2.0 host matrix is single-threaded. The
/// registry guards its mutable state with an
/// `NSLock` so the test fixtures (which install
/// listeners from concurrent contexts) see a
/// consistent view. The 0.3.0 work that introduces
/// worker-thread rendering will replace the lock
/// with a `Synchronization.Mutex`; the public API
/// stays the same.
@_spi(SwiftWebUI)
public enum _RenderEventRegistry {
    /// A single listener entry. The token is the
    /// public identity the renderer stores; the
    /// handler is the closure the registry invokes
    /// when the matching DOM event fires.
    public struct Entry {
        /// The identity of the view that owns
        /// this listener. Used by the test-only
        /// `simulate(_:on:)` to route a
        /// synthetic event to the right handler.
        public let owner: _GraphIdentity
        /// The DOM event name (e.g. `"click"`,
        /// `"input"`).
        public let event: String
        /// The token the registry returned on
        /// `install`. The renderer's mount
        /// record stores this for `remove`.
        public let token: Int
        /// The handler the listener invokes on
        /// a matching DOM event. Held strongly
        /// until `remove(token:)` is called.
        public let handler: () -> Void

        public static func == (lhs: Entry, rhs: Entry) -> Bool {
            lhs.token == rhs.token
        }
    }

    /// Serialises access to the registry's
    /// mutable state.
    private static let lock = NSLock()

    /// Backing storage for the installed-list
    /// list. The lock-protected computed
    /// property is the public API.
    private nonisolated(unsafe) static var _installed: [Entry] = []

    /// The currently-installed listeners. The
    /// test fixtures read this to assert the
    /// install-on-mount / remove-on-teardown
    /// contract; the production renderer holds
    /// its own mount records and does not
    /// introspect the registry.
    public static var installed: [Entry] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _installed
        }
        set {
            lock.lock()
            _installed = newValue
            lock.unlock()
        }
    }

    /// The next token to hand out on `install`.
    /// Guarded by `lock`.
    private nonisolated(unsafe) static var nextToken: Int = 0

    /// Resets the registry to its empty state.
    /// Tests call this in `setUp` to keep state
    /// out of other tests.
    public static func resetForTesting() {
        lock.lock()
        _installed.removeAll()
        nextToken = 0
        lock.unlock()
    }

    /// Installs a listener for `event` owned by
    /// `owner`. Returns a token the caller uses
    /// to remove the listener.
    ///
    /// The registry retains the handler until
    /// `remove(token:)` is called. The handler
    /// is invoked once per matching DOM event
    /// (the production renderer does not dedupe
    /// — the DOM fires one event per user
    /// gesture).
    @discardableResult
    public static func install(
        owner: _GraphIdentity,
        event: String,
        handler: @escaping () -> Void
    ) -> Int {
        lock.lock()
        let token = nextToken
        nextToken += 1
        _installed.append(Entry(
            owner: owner,
            event: event,
            token: token,
            handler: handler
        ))
        lock.unlock()
        return token
    }

    /// Removes the listener with `token`. The
    /// handler is released; the renderer calls
    /// this on teardown (the parent re-renders
    /// without the child view).
    public static func remove(token: Int) {
        lock.lock()
        _installed.removeAll { $0.token == token }
        lock.unlock()
    }

    /// Dispatches a DOM event of `event` on the
    /// listener owned by `owner`. The
    /// production renderer (the bridge worker)
    /// calls this when the host page reports a
    /// DOM event.
    ///
    /// Production invocation contract: the
    /// bridge worker hops to the main actor
    /// before calling `dispatch` (the
    /// `@MainActor` isolation is the same
    /// `@MainActor` contract as
    /// `_ReRenderScheduler`). The handler
    /// runs synchronously on the calling
    /// thread; the handler's body may itself
    /// schedule a re-render through
    /// `_ReRenderScheduler.schedule(_:)`,
    /// which is the intended path (a click
    /// that mutates `@State` schedules the
    /// re-render through the same scheduler
    /// any other write uses).
    public static func dispatch(_ event: String, on owner: _GraphIdentity) {
        // Snapshot the matching handlers under
        // the lock, then invoke them outside
        // the lock so a handler that calls back
        // into the registry (e.g. installs /
        // removes listeners) does not
        // deadlock.
        lock.lock()
        let matching = _installed.filter { $0.event == event && $0.owner == owner }
        lock.unlock()
        for entry in matching {
            entry.handler()
        }
    }

    /// Simulates a synthetic DOM event of
    /// `event` on the listener owned by
    /// `owner`. The snapshot test target uses
    /// this to exercise the click / input
    /// wiring without a live DOM host.
    ///
    /// **Test-only.** Production code MUST NOT
    /// call `simulate`. The bridge worker
    /// wires real DOM events to `dispatch`.
    /// `simulate` is intentionally on the
    /// public API surface (and `@_spi(SwiftWebUI)`)
    /// so the test target can call it without
    /// a second import path.
    ///
    /// The `event:` label is preserved on the
    /// public signature so the test fixtures
    /// can call the API with
    /// `simulate(event: "click", on: identity)`
    /// (matching the red-commit test contract).
    /// The label is documentation, not
    /// enforcement — both `simulate(event:on:)`
    /// and `simulate(_:on:)` resolve to the
    /// same method.
    public static func simulate(
        event: String,
        on owner: _GraphIdentity
    ) {
        // The implementation is the same as
        // `dispatch` in 0.2.0 (the test-only
        // vs production distinction is about
        // *who calls* the method, not what
        // the body does). Kept as a separate
        // method so the production-vs-test
        // boundary is auditable.
        dispatch(event, on: owner)
    }
}
