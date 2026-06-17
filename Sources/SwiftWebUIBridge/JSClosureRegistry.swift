// Sources/SwiftWebUIBridge/JSClosureRegistry.swift
//
// The v0.2.0 `JSClosure` retain policy. See
// `.harness/docs/js-bridge.md` for the contract this file
// implements:
//
//   "Every `JSClosure` is wrapped in a `BridgedClosure` value
//    type that owns a single strong reference plus an integer
//    handle. The handle is registered in a per-renderer
//    `JSClosureRegistry` (`var registry: [Int: JSClosure]`)
//    on the `Renderer` instance. When the Swift view that
//    produced the closure is disposed (graph diff drops the
//    node), the bridge sends a `releaseClosure(handle)` to
//    JS and removes the entry from the registry."
//
// This file hosts the host-runnable surface of the bridge
// (the `JSClosureRegistry` map and the `BridgedClosure`
// value type). It does not call into the JavaScriptKit
// runtime directly — the runtime teardown lives on the
// `JSClosureProtocol.release()` implementation that the
// registry delegates to, which is `JSClosure`'s job on
// wasm32. On the host triple (macOS) the protocol is
// satisfied by a test mock, which is how
// `Tests/SwiftWebUIBridgeTests/JSClosureRegistryTests.swift`
// exercises the map's round-trip without a real
// `swjs_release_function` call.
//
// ## Threading
//
// The 0.2.0 renderer is single-threaded; the registry's
// internal map is guarded by an `NSLock` so that
// `_ReRenderScheduler` and a future event-delegation worker
// thread can share a registry without data races. The
// `JSClosureProtocol` instances themselves are not required
// to be `Sendable`; the lock only protects the
// `[Int: Closure]` storage.

import Foundation
import JavaScriptKit

/// A per-renderer map from integer handle to a JavaScript
/// closure.
///
/// ## Discussion
///
/// The renderer allocates one `JSClosureRegistry` per
/// `Renderer` instance. The graph-diff pass calls
/// `register(_:)` for every `JSClosure` it produces during a
/// render, and `release(_:)` for every handle the diff
/// determines has dropped. `releaseAll()` is the emergency
/// valve: the renderer calls it on its own deinit so a
/// long-lived renderer that is dropped does not leak JS
/// closures back into the host page.
///
/// Handles are positive monotonically-increasing integers.
/// The first `register(_:)` returns `1`, the next `2`, and
/// so on. Handles are unique for the lifetime of the
/// registry; the renderer is responsible for re-using a
/// freed handle only after `release(_:)` has been observed.
///
/// ## Example
///
/// ```swift
/// let registry = JSClosureRegistry()
/// let handle = registry.register(closure)
/// // ...the renderer hands the handle to JS via the DOM
/// // patch, then later, when the diff drops the node...
/// registry.release(handle)
/// ```
@_spi(SwiftWebUI)
public final class JSClosureRegistry: @unchecked Sendable {
    /// The type of closure stored in the registry. The
    /// `any` existential lets test mocks (`MockJSClosure`)
    /// satisfy the protocol on the host triple; on wasm32 the
    /// real `JSClosure` from JavaScriptKit is the canonical
    /// witness.
    public typealias Closure = any JSClosureProtocol

    private let lock = NSLock()
    private var storage: [Int: Closure] = [:]
    private var nextHandle: Int = 1

    /// Creates an empty registry. The first `register(_:)`
    /// returns handle `1`.
    public init() {}

    /// The number of currently registered closures.
    ///
    /// The count goes up by one on every `register(_:)` and
    /// down by one on every `release(_:)` that observes a
    /// known handle. The renderer may use this to detect
    /// leaks: a renderer that exits a render with a
    /// non-zero `count` has dropped handles it never released.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }

    /// Stores `closure` in the registry and returns its
    /// integer handle.
    ///
    /// The handle is unique for the lifetime of the
    /// registry. Callers must keep the returned handle
    /// alive (typically by way of a `BridgedClosure` value)
    /// until the closure is no longer reachable from the
    /// JS side.
    @discardableResult
    public func register(_ closure: Closure) -> Int {
        lock.lock()
        let handle = nextHandle
        nextHandle += 1
        storage[handle] = closure
        lock.unlock()
        return handle
    }

    /// Returns the closure registered at `handle`, or `nil`
    /// if no such handle exists.
    public func get(_ handle: Int) -> Closure? {
        lock.lock()
        defer { lock.unlock() }
        return storage[handle]
    }

    /// Releases the closure registered at `handle`.
    ///
    /// If `handle` is known, the entry is removed and the
    /// closure's `release()` is invoked. If `handle` is
    /// unknown (or has already been released), the call is
    /// a silent no-op. The `idempotent release` contract
    /// lets the renderer safely call `release(_:)` twice
    /// from two code paths without trapping.
    public func release(_ handle: Int) {
        lock.lock()
        let closure = storage.removeValue(forKey: handle)
        lock.unlock()
        closure?.release()
    }

    /// Releases every registered closure.
    ///
    /// The renderer's deinit calls `releaseAll()`. The
    /// contract is the same as `release(_:)`, applied to
    /// every entry: the closures' `release()` is invoked,
    /// the storage is cleared, and the registry is left
    /// empty.
    public func releaseAll() {
        lock.lock()
        let all = Array(storage.values)
        storage.removeAll()
        lock.unlock()
        for closure in all {
            closure.release()
        }
    }
}

/// A Swift value type that owns a registered `JSClosure`
/// handle for its lifetime.
///
/// ## Discussion
///
/// `BridgedClosure` is the "RAII wrapper" the
/// `.harness/docs/js-bridge.md` retain policy is built
/// around. Construction registers the closure in a
/// `JSClosureRegistry` and returns the handle; deinit
/// releases the entry. A Swift view that holds a
/// `BridgedClosure` as a stored property therefore
/// cannot leak its JS callback: the moment the view
/// is deallocated, the handle is released and the JS
/// function freed.
///
/// The struct is a value type, not a class, on purpose:
/// value semantics make the lifetime rule ("the handle is
/// released when the last reference drops") automatic,
/// without a manual `release()` call at every call site.
///
/// ## Example
///
/// ```swift
/// let bridged = BridgedClosure(
///     handle: registry.register(closure),
///     closure: closure,
///     in: registry
/// )
/// // ...later, when `bridged` goes out of scope, the
/// // registry releases the handle and the closure.
/// ```
@_spi(SwiftWebUI)
public struct BridgedClosure: ~Copyable {
    /// The integer handle under which the closure is
    /// registered. Stable for the lifetime of the
    /// `BridgedClosure` value.
    public let handle: Int

    /// The strong reference to the JS closure. Retained
    /// until the `BridgedClosure` is dropped or the
    /// registry releases the handle explicitly.
    public let closure: any JSClosureProtocol

    /// The registry that owns the handle. Held strongly so
    /// the registry outlives the bridged value; otherwise
    /// the deinit's `release(handle)` would dispatch to a
    /// deallocated registry.
    private let registry: JSClosureRegistry

    /// Creates a `BridgedClosure` that registers `closure`
    /// in `registry` and returns the handle.
    ///
    /// - Parameters:
    ///   - handle: The handle returned by
    ///     `JSClosureRegistry.register(_:)`.
    ///   - closure: The closure that was registered. The
    ///     `BridgedClosure` retains it.
    ///   - registry: The registry that owns the handle.
    public init(
        handle: Int,
        closure: any JSClosureProtocol,
        in registry: JSClosureRegistry
    ) {
        self.handle = handle
        self.closure = closure
        self.registry = registry
    }

    /// Releases the registry entry.
    ///
    /// Swift invokes the deinit when the last reference to
    /// the value drops. The registry's `release(_:)` is
    /// idempotent on an unknown handle, so a `BridgedClosure`
    /// that has already had its handle released by an
    /// explicit `registry.release(_:)` call still drops
    /// cleanly.
    ///
    /// The struct is `~Copyable` so that a single
    /// `BridgedClosure` has exactly one owner; the deinit
    /// fires once, at the end of that owner's lifetime,
    /// and not on every copy. This is the single-owner
    /// contract the `.harness/docs/js-bridge.md` retain
    /// policy is built around.
    deinit {
        registry.release(handle)
    }
}
