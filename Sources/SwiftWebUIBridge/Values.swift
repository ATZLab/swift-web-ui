// Sources/SwiftWebUIBridge/Values.swift
//
// Swift ↔ JS value-conversion helpers. See
// `.harness/docs/js-bridge.md` §"Swift ↔ JS value
// conversion" for the locked contract:
//
//   "JSValue ↔ Swift primitive helpers (string, bool, int,
//    double, array, object). Helpers live in
//    Sources/SwiftWebUIBridge/Values.swift."
//
// The primitive encoders and decoders are
// JavaScriptKit-runtime-free — they only use the
// `JSValue` static constructors (`.boolean`, `.string`,
// `.number`) and accessors (`.boolean`, `.string`,
// `.number`), all of which are pure-Swift paths on
// `JSValue`. This lets the host (macOS) test target
// round-trip a `String` / `Bool` / `Int` / `Double` without
// a live wasm runtime.
//
// The array and object helpers touch `JSObject.global`
// (which is `LazyThreadLocal` over `swjs_get_global`).
// That is a wasi-only runtime call, so the array and
// object surface is `#if os(WASI)`-gated. The
// `ValuesCollectionRoundTripTests` are also `os(WASI)`-gated
// and exercise this surface in the wasm32 CI matrix.

import JavaScriptKit

/// Type-safe Swift ↔ JS value-conversion helpers.
///
/// ## Discussion
///
/// `Values` is a namespace of pure functions that wrap
/// `JSValue`'s static constructors and accessors. The
/// goal is to give renderer and user code a single,
/// discoverable place to convert between Swift and JS
/// values, instead of reaching for the untyped
/// `value.jsValue` and `value.string` property accessors
/// scattered across the framework.
///
/// Primitive encoders (`toJSValue(_:)`) and decoders
/// (`string(from:)`, `bool(from:)`, etc.) are always
/// available. The array and object helpers are gated to
/// the wasm32 host because they allocate a `JSObject`
/// on the JS side, which links the JavaScriptKit C
/// runtime that is not present on macOS.
///
/// ## Example
///
/// ```swift
/// let js = Values.toJSValue("hello")
/// let back = Values.string(from: js)  // Optional("hello")
///
/// let count = Values.toJSValue(42)
/// let n = Values.int(from: count)     // Optional(42)
/// ```
@_spi(SwiftWebUI)
public enum Values {

    // MARK: - Primitive encoders (host-runnable)

    /// Wraps a Swift `String` in a `JSValue`.
    public static func toJSValue(_ value: String) -> JSValue {
        value.jsValue
    }

    /// Wraps a Swift `Bool` in a `JSValue`.
    public static func toJSValue(_ value: Bool) -> JSValue {
        value.jsValue
    }

    /// Wraps a Swift `Int` in a `JSValue`.
    ///
    /// The implementation goes through `Double` rather
    /// than `Int.jsValue` to bypass JavaScriptKit's
    /// `assert(Int.bitWidth == 32)` — the canonical
    /// Swift `Int` on `wasm32-unknown-wasi` is 32 bits,
    /// but the bridge's host triple (macOS) is 64 bits,
    /// where the assertion fires on every call. The
    /// resulting `JSValue` is a number that decodes back
    /// to the original `Int` via `Values.int(from:)` for
    /// any value that fits in `Int32` without precision
    /// loss.
    public static func toJSValue(_ value: Int) -> JSValue {
        .number(Double(value))
    }

    /// Wraps a Swift `Double` in a `JSValue`.
    public static func toJSValue(_ value: Double) -> JSValue {
        value.jsValue
    }

    // MARK: - Primitive decoders (host-runnable)

    /// Extracts a Swift `String` from a `JSValue`, or
    /// returns `nil` if the value is not a JavaScript
    /// string.
    public static func string(from value: JSValue) -> String? {
        value.string
    }

    /// Extracts a Swift `Bool` from a `JSValue`, or returns
    /// `nil` if the value is not a JavaScript boolean.
    public static func bool(from value: JSValue) -> Bool? {
        value.boolean
    }

    /// Extracts a Swift `Int` from a `JSValue`, or returns
    /// `nil` if the value is not a JavaScript number that
    /// fits in an `Int` without rounding.
    public static func int(from value: JSValue) -> Int? {
        guard let number = value.number else { return nil }
        return Int(exactly: number)
    }

    /// Extracts a Swift `Double` from a `JSValue`, or
    /// returns `nil` if the value is not a JavaScript
    /// number.
    public static func double(from value: JSValue) -> Double? {
        value.number
    }
}

#if os(WASI)
extension Values {
    // MARK: - Collection encoders (wasm32-only)

    /// Wraps a Swift array in a JavaScript array
    /// (`JSArray`).
    ///
    /// The encoder allocates a fresh `JSObject` via
    /// `Array.from(...)` on the JS side, then assigns
    /// each element to its index. The resulting
    /// `JSValue.object` is the new array.
    public static func toJSValue<T: ConvertibleToJSValue>(
        _ array: [T]
    ) -> JSValue {
        let arrayConstructor = JSObject.global.Array.function!
        let jsArray = arrayConstructor.new(arguments: [array.count])
        for (index, element) in array.enumerated() {
            jsArray[index] = element.jsValue
        }
        return .object(jsArray)
    }

    /// Wraps a Swift dictionary in a JavaScript object
    /// literal (`{ key: value, ... }`).
    ///
    /// The encoder allocates a fresh `JSObject` via
    /// `Object.create(null)`-equivalent on the JS side,
    /// then assigns each key/value pair.
    public static func toJSValue<V: ConvertibleToJSValue>(
        _ object: [String: V]
    ) -> JSValue {
        let objectConstructor = JSObject.global.Object.function!
        let jsObject = objectConstructor.new(arguments: [])
        for (key, value) in object {
            jsObject[key] = value.jsValue
        }
        return .object(jsObject)
    }

    // MARK: - Collection decoders (wasm32-only)

    /// Decodes a `JSValue` as a Swift array of `T`.
    ///
    /// Returns `nil` if `value` is not a JavaScript array
    /// or if any element fails the `T.construct(from:)`
    /// conversion. Elements that successfully construct are
    /// kept in the result; elements that fail are dropped.
    public static func array<T: ConstructibleFromJSValue>(
        of type: T.Type,
        from value: JSValue
    ) -> [T]? {
        guard let jsArray = value.array else { return nil }
        var result: [T] = []
        result.reserveCapacity(jsArray.length)
        for index in 0..<jsArray.length {
            if let element = T.construct(from: jsArray[index]) {
                result.append(element)
            }
        }
        return result
    }

    /// Decodes a `JSValue` as a Swift `[String: T]`.
    ///
    /// Returns `nil` if `value` is not a JavaScript object.
    /// Object keys are read with `Object.keys(...)`; values
    /// that fail the `T.construct(from:)` conversion are
    /// dropped from the result.
    public static func object<T: ConstructibleFromJSValue>(
        of type: T.Type,
        from value: JSValue
    ) -> [String: T]? {
        guard let jsObject = value.object else { return nil }
        let keys = JSObject.global.Object.function!
            .keys!(jsObject)
            .array
        var result: [String: T] = [:]
        guard let keysArray = keys else { return result }
        for index in 0..<keysArray.length {
            let key = keysArray[index].string ?? ""
            if let v = T.construct(from: jsObject[key]) {
                result[key] = v
            }
        }
        return result
    }
}
#endif
