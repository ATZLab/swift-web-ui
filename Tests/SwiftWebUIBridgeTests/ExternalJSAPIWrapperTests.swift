// Tests/SwiftWebUIBridgeTests/ExternalJSAPIWrapperTests.swift
//
// RED (v0.2.0 phase 2-4) — typed wrappers for `window.alert`
// and `console.log`.
//
// The bridge exposes a typed Swift surface for the browser
// APIs that user code is most likely to call. The contract is
// in `.harness/docs/js-bridge.md` §"External JS API bindings":
//
//   "window.alert(_:) — typed wrapper. console.log(_:) — typed
//    wrapper. fetch(_:) — typed wrapper returning Result."
//
// `window` and `console` live on `JSObject.global`. The
// `Bridge.alert(_:)` and `Bridge.consoleLog(_:)` helpers look
// them up through the registry's typed surface. The tests
// need a live `JSObject.global` to invoke the underlying JS
// functions, which the JSKit runtime can only construct on
// `wasm32-unknown-wasi`. Gated to `os(WASI)`.

#if os(WASI)
import JavaScriptKit
import Testing
@testable import SwiftWebUIBridge

@Suite("window.alert wrapper (wasm32-only, v0.2.0 phase 2-4)")
struct WindowAlertWrapperTests {

    @Test("Bridge.alert(_:) is invokable from Swift")
    func bridgeAlertIsInvokable() {
        // The wrapper's contract: it takes a String, calls
        // `globalThis.alert(message)`, and returns Void. The
        // assertion is that the call does not trap on a
        // well-formed input. A wasm32 CI run with a stub
        // `globalThis.alert` (a no-op function) is the
        // canonical environment for this test; the wrapper
        // ships to the browser unchanged.
        Bridge.alert("hello from the bridge")
    }
}

@Suite("console.log wrapper (wasm32-only, v0.2.0 phase 2-4)")
struct ConsoleLogWrapperTests {

    @Test("Bridge.consoleLog(_:) is invokable from Swift")
    func bridgeConsoleLogIsInvokable() {
        // The wrapper's contract: it takes a String, calls
        // `globalThis.console.log(message)`, and returns
        // Void. The wasm32 host asserts the call dispatches
        // through to the runtime; a Playwright-driven
        // assertion of the captured console message is the
        // 0.3.0 WebDriver follow-up (see
        // `.harness/docs/tdd.md`).
        Bridge.consoleLog("hello from the bridge")
    }
}
#endif
