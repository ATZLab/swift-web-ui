// Tests/SwiftWebUIBridgeTests/JSClosureRegistryTests.swift
//
// RED (v0.2.0 phase 2-4) — host-runnable unit tests for the
// `JSClosureRegistry` retain policy. See
// `.harness/docs/js-bridge.md` for the contract:
//
//   "Every `JSClosure` is wrapped in a `BridgedClosure` value
//   type that owns a single strong reference plus an integer
//   handle. The handle is registered in a per-renderer
//   `JSClosureRegistry` (`var registry: [Int: JSClosure]`) on
//   the `Renderer` instance. When the Swift view that produced
//   the closure is disposed (graph diff drops the node), the
//   bridge sends a `releaseClosure(handle)` to JS and removes
//   the entry from the registry."
//
// The tests verify the **map's behaviour**, not the runtime
// `swjs_release_function` C ABI. They use a `MockJSClosure` that
// conforms to `JSClosureProtocol` so the round-trip
// (register → get → release → empty) can be exercised on the
// host triple (macOS) without a live JavaScriptKit runtime.
//
// The runtime side of the contract — that the `release()` call
// on the real `JSClosure` invokes the C ABI that frees the JS
// function — is an `os(WASI)`-gated concern; the
// `JavaScriptKitCallsiteSmokeTests` (added in 0.3.0) cover it
// under a wasm32 host.

import JavaScriptKit
import Testing
@testable import SwiftWebUIBridge

/// A test double that satisfies `JSClosureProtocol` without
/// touching the JavaScriptKit runtime. Records `release()`
/// invocations on a public flag so tests can assert the
/// registry actually fired the teardown.
final class MockJSClosure: JSClosureProtocol, @unchecked Sendable {
    /// Stable identifier so test failures can name the closure.
    let identifier: String

    /// `true` after `release()` has been called. Tests use this
    /// to assert the registry actually invoked teardown.
    private(set) var didRelease = false

    /// The number of times `release()` was called. Mock releases
    /// are idempotent in production; a count greater than one
    /// would indicate a double-release bug.
    private(set) var releaseCount = 0

    init(identifier: String) {
        self.identifier = identifier
    }

    var jsValue: JSValue {
        // The mock never crosses into JS. Returning `.undefined`
        // is the closest possible representation; the registry
        // does not inspect `jsValue` on the host path.
        .undefined
    }

    static func construct(from value: JSValue) -> Self? {
        // The mock is only constructed directly by tests; the
        // JSValue decoder path is not exercised on host.
        nil
    }

    func release() {
        releaseCount += 1
        didRelease = true
    }
}

@Suite("JSClosureRegistry")
struct JSClosureRegistryTests {

    @Test("a fresh registry is empty")
    func freshRegistryIsEmpty() {
        let registry = JSClosureRegistry()
        #expect(registry.count == 0)
    }

    @Test("register returns a positive handle and bumps the count")
    func registerReturnsHandleAndBumpsCount() {
        let registry = JSClosureRegistry()
        let closure = MockJSClosure(identifier: "a")
        let handle = registry.register(closure)
        #expect(handle > 0)
        #expect(registry.count == 1)
    }

    @Test("two register calls produce two distinct handles")
    func twoRegistersProduceDistinctHandles() {
        let registry = JSClosureRegistry()
        let h1 = registry.register(MockJSClosure(identifier: "a"))
        let h2 = registry.register(MockJSClosure(identifier: "b"))
        #expect(h1 != h2)
        #expect(registry.count == 2)
    }

    @Test("get returns the registered closure for a known handle")
    func getReturnsRegisteredClosure() {
        let registry = JSClosureRegistry()
        let closure = MockJSClosure(identifier: "a")
        let handle = registry.register(closure)
        let resolved = registry.get(handle)
        #expect(resolved?.identifier == "a")
    }

    @Test("get returns nil for an unknown handle")
    func getReturnsNilForUnknownHandle() {
        let registry = JSClosureRegistry()
        let resolved = registry.get(99_999)
        #expect(resolved == nil)
    }

    @Test("release removes the entry and decrements the count")
    func releaseRemovesEntry() {
        let registry = JSClosureRegistry()
        let handle = registry.register(MockJSClosure(identifier: "a"))
        #expect(registry.count == 1)
        registry.release(handle)
        #expect(registry.count == 0)
        #expect(registry.get(handle) == nil)
    }

    @Test("release invokes the closure's release()")
    func releaseInvokesClosureRelease() {
        let registry = JSClosureRegistry()
        let closure = MockJSClosure(identifier: "a")
        let handle = registry.register(closure)
        #expect(closure.didRelease == false)
        registry.release(handle)
        #expect(closure.didRelease == true)
    }

    @Test("release on an unknown handle is a silent no-op")
    func releaseOnUnknownHandleIsNoop() {
        let registry = JSClosureRegistry()
        // No prior register; the release must not trap or
        // affect the (empty) registry.
        registry.release(99_999)
        #expect(registry.count == 0)
    }

    @Test("releaseAll releases every registered closure")
    func releaseAllReleasesEveryClosure() {
        let registry = JSClosureRegistry()
        let a = MockJSClosure(identifier: "a")
        let b = MockJSClosure(identifier: "b")
        let c = MockJSClosure(identifier: "c")
        registry.register(a)
        registry.register(b)
        registry.register(c)
        #expect(registry.count == 3)
        registry.releaseAll()
        #expect(registry.count == 0)
        #expect(a.didRelease)
        #expect(b.didRelease)
        #expect(c.didRelease)
    }

    @Test("releasing a handle twice is safe (idempotent)")
    func releasingTwiceIsSafe() {
        let registry = JSClosureRegistry()
        let closure = MockJSClosure(identifier: "a")
        let handle = registry.register(closure)
        registry.release(handle)
        // The second call must not trap. The mock is the
        // witness: the closure's `release()` is called once
        // (the first call). A second call against the same
        // handle is a no-op because the registry no longer
        // has the entry.
        registry.release(handle)
        #expect(closure.releaseCount == 1)
    }
}

@Suite("BridgedClosure value-type retain (v0.2.0 phase 2-4)")
struct BridgedClosureTests {

    @Test("dropping a BridgedClosure releases its registry entry")
    func droppingBridgedClosureReleasesRegistryEntry() {
        let registry = JSClosureRegistry()
        let closure = MockJSClosure(identifier: "owner")
        let handle = registry.register(closure)
        #expect(registry.count == 1)

        do {
            let bridged = BridgedClosure(handle: handle, closure: closure, in: registry)
            #expect(bridged.handle == handle)
            #expect(registry.count == 1)
            #expect(closure.didRelease == false)
        }

        // The local `bridged` is now out of scope. Its
        // deinit must release the registry entry.
        #expect(registry.count == 0)
        #expect(closure.didRelease == true)
    }

    @Test(
        "two BridgedClosures with distinct handles are tracked independently"
    )
    func twoBridgedClosuresTrackedIndependently() {
        let registry = JSClosureRegistry()
        let a = MockJSClosure(identifier: "a")
        let b = MockJSClosure(identifier: "b")
        let bridgedA = BridgedClosure(
            handle: registry.register(a),
            closure: a,
            in: registry
        )
        let bridgedB = BridgedClosure(
            handle: registry.register(b),
            closure: b,
            in: registry
        )
        #expect(bridgedA.handle != bridgedB.handle)

        // Drop A. B must still be alive.
        _ = bridgedA
        #expect(a.didRelease)
        #expect(!b.didRelease)
        #expect(registry.count == 1)
    }
}
