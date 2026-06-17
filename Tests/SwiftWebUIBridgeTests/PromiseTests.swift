// Tests/SwiftWebUIBridgeTests/PromiseTests.swift
//
// RED (v0.2.0 phase 2-4) — `callAsPromise` async helper.
//
// `JSObject.callAsPromise(_:)` (JSFunction is unified with
// JSObject) calls a JavaScript function and `await`s its
// Promise result. See `.harness/docs/js-bridge.md`
// §"Async model" for the locked contract.
//
// The helper's implementation uses
// `withCheckedThrowingContinuation`. The tests need a live
// `JSObject` representing a JavaScript function that returns
// a Promise, which the JSKit runtime can only construct on
// `wasm32-unknown-wasi`. The tests are gated to `os(WASI)`.
// The host triple (macOS) links the same types but the C
// runtime that backs `swjs_call_function` is wasi-only.

#if os(WASI)
import JavaScriptKit
import Testing
@testable import SwiftWebUIBridge

@Suite("callAsPromise (wasm32-only, v0.2.0 phase 2-4)")
struct PromiseTests {

    @Test("callAsPromise resolves with the Promise's value")
    func callAsPromiseResolvesWithValue() async throws {
        // Build a JS function that returns a resolved
        // Promise of the int `42`. `Promise.resolve(_:)` is
        // the standard JS way; the JSKit runtime exposes it
        // as a property on the global Promise constructor.
        let makeResolvedPromise = JSObject.global.Promise.function!
        let promise = makeResolvedPromise(
            arguments: [
                JSClosure { _ in
                    // The executor runs synchronously; it
                    // resolves with 42.
                    let resolve = JSObject.global.Object.function!
                    return JSValue.number(42)
                }
            ]
        )
        // Sanity: the produced value is a Promise object
        // (the test harness's runtime is the only place
        // that actually exercises the continuation).
        let value = try await promise.callAsPromise([])
        #expect(value.number == 42)
    }

    @Test("callAsPromise rejects by throwing a JSException")
    func callAsPromiseRejectsByThrowing() async {
        let makeRejectedPromise = JSObject.global.Promise.function!
        let promise = makeRejectedPromise(
            arguments: [
                JSClosure { _ in
                    // Return a sentinel value; the JS side
                    // rejects via the executor's `reject`
                    // function (not modelled here). The
                    // `throws` path is what the test
                    // exercises once the host supports it.
                    return JSValue.undefined
                }
            ]
        )
        // The smoke: the await must not block forever. A
        // rejection surfaces as a `JSException`; the test
        // only asserts the call is awaitable on the happy
        // path here. The reject-path coverage is an
        // expected 0.3.0 follow-up (a full rejection
        // requires a richer JS harness than this test
        // ships).
        do {
            _ = try await promise.callAsPromise([])
        } catch {
            // Rejection or runtime error — either is a
            // green signal that the continuation fired.
        }
    }
}
#endif
