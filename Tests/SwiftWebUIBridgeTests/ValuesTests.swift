// Tests/SwiftWebUIBridgeTests/ValuesTests.swift
//
// RED (v0.2.0 phase 2-4) — Swift ↔ JS value-conversion round-trips.
//
// The bridge exposes type-safe wrappers around `JSValue`'s
// static constructors and accessors (see
// `.harness/docs/js-bridge.md` §"Swift ↔ JS value conversion").
// The round-trips exercise the **static** path: a Swift value
// is wrapped via `Values.toJSValue(_:)` and the result is
// unwrapped via `Values.<primitive>(from:)`. Because the static
// constructors on `JSValue` (`.boolean`, `.string`, `.number`)
// do not touch the JavaScriptKit runtime, the primitive
// round-trips run on the host triple (macOS).
//
// The `array` and `object` round-trips need to allocate a
// `JSObject` on the JS side, which links the JSKit runtime
// (`swjs_call_function` and friends). Those tests are gated
// to `os(WASI)` and will be exercised by the wasm32 CI matrix
// in 0.3.0 (the `JavaScriptKitCallsiteSmokeTests` target).

import JavaScriptKit
import Testing
@testable import SwiftWebUIBridge

@Suite("Values primitive round-trips (v0.2.0 phase 2-4)")
struct ValuesPrimitiveRoundTripTests {

    @Test("string round-trips through JSValue")
    func stringRoundTrip() {
        let original = "Hello, web in Swift"
        let js = Values.toJSValue(original)
        let decoded = Values.string(from: js)
        #expect(decoded == original)
    }

    @Test("bool round-trips through JSValue")
    func boolRoundTrip() {
        for original in [true, false] {
            let js = Values.toJSValue(original)
            let decoded = Values.bool(from: js)
            #expect(decoded == original)
        }
    }

    @Test("int round-trips through JSValue")
    func intRoundTrip() {
        for original in [0, 1, -1, 42, Int.max, Int.min] {
            let js = Values.toJSValue(original)
            let decoded = Values.int(from: js)
            #expect(decoded == original)
        }
    }

    @Test("double round-trips through JSValue")
    func doubleRoundTrip() {
        for original in [0.0, 3.14, -2.71, 1.0e10] {
            let js = Values.toJSValue(original)
            let decoded = Values.double(from: js)
            // `Int`-vs-`Double` are not bit-identical for
            // huge values, but the IEEE-754 round-trip is.
            #expect(decoded == original)
        }
    }

    @Test("decoding the wrong primitive returns nil")
    func decodingWrongPrimitiveReturnsNil() {
        let jsString = Values.toJSValue("not a number")
        #expect(Values.int(from: jsString) == nil)
        #expect(Values.bool(from: jsString) == nil)
        #expect(Values.double(from: jsString) == nil)
    }
}

#if os(WASI)
/// The array / object encoders allocate a `JSObject` via the
/// JSKit runtime. Host (macOS) builds link the same types but
/// the C runtime is wasi-only, so the runtime calls would
/// trap. Gated to `os(WASI)` until the 0.3.0 wasm32 host test
/// target lands.
@Suite("Values collection round-trips (wasm32-only, v0.2.0 phase 2-4)")
struct ValuesCollectionRoundTripTests {

    @Test("string array round-trips through a JSArray")
    func stringArrayRoundTrip() throws {
        let original = ["alpha", "beta", "gamma"]
        let js = Values.toJSValue(original)
        let decoded = try #require(Values.array(of: String.self, from: js))
        #expect(decoded == original)
    }

    @Test("int array round-trips through a JSArray")
    func intArrayRoundTrip() throws {
        let original = [1, 2, 3, 4, 5]
        let js = Values.toJSValue(original)
        let decoded = try #require(Values.array(of: Int.self, from: js))
        #expect(decoded == original)
    }

    @Test("string→int object round-trips through a JSObject")
    func objectRoundTrip() throws {
        let original: [String: Int] = [
            "alpha": 1,
            "beta": 2,
            "gamma": 3,
        ]
        let js = Values.toJSValue(original)
        let decoded = try #require(Values.object(of: Int.self, from: js))
        #expect(decoded == original)
    }
}
#endif
