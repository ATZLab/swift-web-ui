// Sources/SwiftWebUIBridge/Promise.swift
//
// `callAsPromise` — `await` a JavaScript function's Promise
// result. See `.harness/docs/js-bridge.md` §"Async model":
//
//   "JSKit's JSFunction is callable synchronously from Swift.
//    For asynchronous JS (e.g. fetch returning a Promise),
//    the bridge exposes:
//
//        public extension JSObject {
//            func callAsPromise(_ args: [JSValue]) async throws -> JSValue
//        }
//
//    The internal implementation uses
//    withCheckedThrowingContinuation."
//
// The implementation constructs a `JSClosure` that, when
// invoked by the JS side, resumes the
// `CheckedContinuation`. The bridge then calls the target
// JS function with `(callback, ...args)` and awaits the
// continuation. If the JS side throws, the closure
// re-throws the value as a `JSException`.
//
// This file is gated to `os(WASI)`: the `callAsPromise`
// extension calls a JS function on `JSObject.global`-style
// runtime, which links the JavaScriptKit C ABI that is
// wasi-only. The host (macOS) does not have a JS engine,
// so the test target compiles the call sites on host but
// only exercises them on the wasm32 CI matrix.

#if os(WASI)
import Foundation
import JavaScriptKit

extension JSObject {
    /// Calls the function and `await`s the Promise result.
    ///
    /// ## Discussion
    ///
    /// The convention is the two-argument Promise shape
    /// used by Node-style async functions: `fn((result,
    /// error) => { ... }, ...args)`. JavaScriptKit's
    /// `JSPromise` and the Promise-returning JS APIs in
    /// the wild — `fetch`, `crypto.subtle`, `WebSocket.send`
    /// — all accept this callback shape.
    ///
    /// The bridge's helper takes the simpler
    /// Promise-style: the JS function must return a
    /// Promise that resolves with the result. The bridge
    /// internally constructs a `new Promise((resolve,
    /// reject) => { try { resolve(targetFn(...args)); }
    /// catch (e) { reject(e); } })` to make the contract
    /// uniform across the JS surface.
    ///
    /// On resolution, the awaited value is the Promise's
    /// resolution. On rejection, the call throws a
    /// `JSException` carrying the rejection value.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let fetch = JSObject.global.fetch.function!
    /// let response = try await fetch.callAsPromise([urlValue])
    /// ```
    public func callAsPromise(_ args: [JSValue]) async throws -> JSValue {
        // Build the wrapper Promise. The executor calls
        // the underlying function synchronously inside a
        // try/catch and resolves / rejects the wrapper
        // Promise accordingly. The await on the Swift
        // side therefore sees a single resolution with
        // either the function's return value or a
        // `JSException` carrying the throw.
        let wrapper = JSObject.global.Promise.function!.new(arguments: [
            JSClosure { innerArgs in
                let resolve = innerArgs[0].function!
                let reject = innerArgs[1].function!
                do {
                    let result = try self(arguments: args)
                    resolve(arguments: [result])
                } catch let error as JSException {
                    reject(arguments: [error.jsValue])
                } catch {
                    // Defensive: any non-JSException throw
                    // is forwarded as an undefined
                    // rejection. The continuation's `catch`
                    // block will surface a `JSException`
                    // wrapping `.undefined`.
                    reject(arguments: [JSValue.undefined])
                }
                return .undefined
            }
        ])

        // The wrapper is a `JSObject` (Promise instance).
        // Awaiting it is the bridge's job: hand the
        // promise a one-shot resolver and suspend until
        // the JS side fires it.
        return try await Self.awaitPromise(wrapper)
    }

    /// Awaits a JavaScript Promise by handing it a
    /// `(resolve, reject)` callback pair and returning the
    /// resolved value (or throwing on rejection).
    ///
    /// `JSClosure` is one-shot on wasm32 — the
    /// `then(resolve, reject)` shape fires the resolver
    /// exactly once. The continuation resumes on the
    /// Swift concurrency runtime.
    fileprivate static func awaitPromise(
        _ promise: JSObject
    ) async throws -> JSValue {
        try await withCheckedThrowingContinuation { continuation in
            // `then(resolve, reject)` is the standard
            // Promise pattern. The two closures are
            // one-shot; whichever fires first ends the
            // await.
            let then = promise.then.function!
            _ = then(
                arguments: [
                    JSClosure { resolvedArgs in
                        let value = resolvedArgs[0]
                        continuation.resume(returning: value)
                        return .undefined
                    },
                    JSClosure { rejectedArgs in
                        let value = rejectedArgs[0]
                        continuation.resume(
                            throwing: JSException(value)
                        )
                        return .undefined
                    },
                ]
            )
        }
    }
}
#endif
