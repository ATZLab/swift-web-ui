// Sources/SwiftWebUIBridge/ExternalJSAPI.swift
//
// Typed Swift wrappers for the browser APIs that user
// code is most likely to call. See
// `.harness/docs/js-bridge.md` §"External JS API bindings":
//
//   "window.alert, console.log, and fetch APIs. They are
//    the reference examples for users who want to bind
//    more."
//
// The wrappers look up the underlying JS function on
// `JSObject.global` (the browser's `globalThis`). The
// wrappers are typed at the Swift level so the renderer
// and user code can call `Bridge.alert("hi")` instead of
// reaching for the untyped `JSObject.global.alert`
// property.
//
// This file is gated to `os(WASI)`: the wrappers call
// into the JavaScriptKit runtime that is wasi-only. The
// host (macOS) does not have a JS engine, so the test
// target compiles the call sites on host but only
// exercises them on the wasm32 CI matrix.

#if os(WASI)
import Foundation
import JavaScriptKit

/// Typed entry points for common browser-side JavaScript
/// APIs.
///
/// ## Discussion
///
/// `Bridge` is the public surface the user-facing API
/// exposes for the few browser globals that are most
/// often called from Swift. The list is intentionally
/// short — `alert`, `console.log`, and `fetch` — and
/// is meant to be the **reference examples** for
/// developers who want to bind more. The
/// `Sources/SwiftWebUIBridge/README.md` file documents
/// the binding DSL.
///
/// The bridge owns the conversion between Swift
/// primitives and `JSValue`. `alert(_:)` and
/// `consoleLog(_:)` take a `String`; `fetch(_:)` takes
/// a `String` URL and returns a `JSValue` Promise
/// (the caller `await`s it with `callAsPromise`).
///
/// ## Example
///
/// ```swift
/// Bridge.consoleLog("started")
/// // ...later in a SwiftUI button's action...
/// Bridge.alert("clicked!")
/// ```
@_spi(SwiftWebUI)
public enum Bridge {

    // MARK: - window.alert

    /// Invokes `window.alert(message)` on the page.
    ///
    /// On the browser, the call surfaces a synchronous
    /// modal dialog. Tests on the wasm32 host assert
    /// the call dispatches; a Playwright-driven
    /// assertion of the captured dialog text is the
    /// 0.3.0 WebDriver follow-up.
    public static func alert(_ message: String) {
        guard let alert = JSObject.global.alert.function else {
            return
        }
        _ = alert(arguments: [message.jsValue])
    }

    // MARK: - console.log

    /// Invokes `console.log(message)` on the page.
    ///
    /// The message is forwarded verbatim; the JS
    /// console formats it according to the browser's
    /// own formatting rules. The bridge's
    /// `JSClosure` call is synchronous, so by the time
    /// `consoleLog(_:)` returns, the message has
    /// reached the JS console.
    public static func consoleLog(_ message: String) {
        guard let consoleObject = JSObject.global.console.object,
              let log = consoleObject.log.function else {
            return
        }
        _ = log(arguments: [message.jsValue])
    }

    // MARK: - fetch (typed wrapper returning a Promise)

    /// Returns the `fetch` function from the JS global
    /// scope, typed as a Swift-typed `JSObject` that the
    /// caller can `await` with `callAsPromise(_:)`.
    ///
    /// The wrapper is intentionally a **getter**, not
    /// an `await` itself, because `fetch` is one of
    /// many Promise-returning browser APIs and the
    /// call site usually wants to `await` multiple of
    /// them concurrently.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let response = try await Bridge.fetch.function!(
    ///     arguments: [urlValue]
    /// ).callAsPromise([])
    /// ```
    public static var fetch: JSObject {
        // `JSObject.global.fetch` returns the function
        // as an `JSValue`; the property access goes
        // through `@dynamicMemberLookup` and unwraps
        // the optional `JSValue` to a `JSObject` via
        // `.object`.
        JSObject.global.fetch.object!
    }
}
#endif
